"""NaviSanté AI gateway.

Flutter → this process → OpenRouter → DeepSeek V4 Flash.

The model never queries the database. Flutter runs tools (cache first,
then existing repository methods). The OpenRouter key stays here —
never in the mobile app.
"""

from __future__ import annotations

import hashlib
import json
import logging
import os
import re
import time
from contextlib import asynccontextmanager
from pathlib import Path
from typing import Any

import httpx
from dotenv import load_dotenv
from fastapi import FastAPI, Header, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel, Field

load_dotenv(Path(__file__).resolve().parent / ".env")

OPENROUTER_API_KEY = os.getenv("OPENROUTER_API_KEY", "").strip()
OPENROUTER_MODEL = os.getenv(
    "OPENROUTER_MODEL", "deepseek/deepseek-v4-flash"
).strip() or "deepseek/deepseek-v4-flash"
GATEWAY_SECRET = os.getenv("GATEWAY_SECRET", "").strip()

MAX_OUTPUT_TOKENS = 400
REQUEST_TIMEOUT_S = 30.0
CONNECT_TIMEOUT_S = 15.0
RATE_LIMIT_PER_MIN = 8
HISTORY_TURNS = 6
HISTORY_CHARS = 400
USER_CHARS = 1200
TOOL_CONTENT_CHARS = 1600
MAX_TOOL_CALLS = 2

SYSTEM = """You are Navi AI, the in-app assistant inside NaviSanté.

NaviSanté is a health-navigation app for Cameroon — the whole country, every region, not only Yaoundé. It is not a hospital, pharmacy, insurer, or doctor. People use it to find real hospitals, clinics and pharmacies, get directions, save facilities, and look up medications in the NaviSanté catalog (brands, Rx vs OTC, CFA price range, retailers).

App layout (do not invent extra screens):
- Home / Map: nearby facility pins, closest highlights, locate-me, Navi AI button.
- Hospitals: search and filter facilities, 2-column cards, full details, bookmarks.
- Pharmacy: medication catalog, search by name / brand / condition (English or French), favourites, tap a retailer for directions.
- Profile: saved facilities, favourite products, account.

You help with NaviSanté facilities and medications, the user's GPS and saved list when provided, and general health information.

Language:
- Cameroon is bilingual. If the user writes French, reply in natural Cameroon French (clear, tutoiement is fine, keep official facility names as stored).
- If the app language is FR, default to French unless the user clearly wrote English.
- If the user writes English, reply in English.
- Do not mix languages in one reply.

Rules:
- Not a doctor. Never diagnose, prescribe, or promise a treatment for this user.
- Red flags (chest pain/tightness, trouble breathing, severe bleeding, stroke signs, pregnancy emergency): brief general info + urge urgent/clinician care now.
- Never invent facilities, distances, hours, phones, prices, stock, services, or bookmarks. Call tools.
- Stay on NaviSanté / health. Off-topic (recipes, code, jokes, homework): one short redirect in the user's language.
- Plain text only. No markdown, HTML, or widget tags.
- Cards under your message already show details, bookmark/favourite, and directions — mention that once, do not repeat card fields.
- Short: a few sentences for simple questions. Usually under 100 words. Never over 250.
- After tools: summarise 1–3 real options. If tools return none, say it was not found in NaviSanté and point the user to Hospitals or Pharmacy search.
"""

TOOLS = [
    {
        "type": "function",
        "function": {
            "name": "search_facilities",
            "description": "Search NaviSanté hospitals, clinics, pharmacies in Cameroon. Flutter uses cache first, then the app database if needed.",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "service": {"type": "string"},
                    "type": {
                        "type": "string",
                        "enum": ["hospital", "clinic", "pharmacy"],
                    },
                    "nearby": {"type": "boolean"},
                },
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "get_facility_detail",
            "description": "One facility by facility_id from search_facilities.",
            "parameters": {
                "type": "object",
                "properties": {"facility_id": {"type": "string"}},
                "required": ["facility_id"],
            },
        },
    },
    {
        "type": "function",
        "function": {
            "name": "search_medications",
            "description": "Search the NaviSanté medication catalog (name, brand, condition, Rx/OTC, retailers).",
            "parameters": {
                "type": "object",
                "properties": {
                    "query": {"type": "string"},
                    "condition": {"type": "string"},
                },
            },
        },
    },
]


class HistoryTurn(BaseModel):
    role: str
    content: str


class ChatContext(BaseModel):
    lat: float | None = None
    lng: float | None = None
    country: str | None = "Cameroon"
    language: str | None = "en"
    bookmark_count: int = 0
    bookmark_names: list[str] = Field(default_factory=list)


class ToolResult(BaseModel):
    tool_call_id: str
    name: str
    content: str
    arguments: str = "{}"


class ChatRequest(BaseModel):
    conversation_id: str
    message: str = Field(default="", max_length=2000)
    history: list[HistoryTurn] = Field(default_factory=list)
    context: ChatContext = Field(default_factory=ChatContext)
    tool_results: list[ToolResult] | None = None


class ToolCallOut(BaseModel):
    id: str
    name: str
    arguments: str


class ChatResponse(BaseModel):
    ok: bool
    text: str = ""
    facility_ids: list[str] = Field(default_factory=list)
    medication_ids: list[str] = Field(default_factory=list)
    tool_calls: list[ToolCallOut] | None = None
    error: str | None = None


_http = httpx.Client(
    timeout=httpx.Timeout(REQUEST_TIMEOUT_S, connect=CONNECT_TIMEOUT_S),
    limits=httpx.Limits(max_keepalive_connections=8, max_connections=16),
)
_buckets: dict[str, dict[str, Any]] = {}
_MD = re.compile(r"[*_`#>]{1,3}")
_FR_HINT = re.compile(
    r"\b(je|tu|vous|nous|le|la|les|des|une|est|sont|hôpital|hopital|"
    r"pharmacie|médicament|medicament|paludisme|fièvre|fievre|où|ou est)\b",
    re.I,
)


def _plain(text: str) -> str:
    return _MD.sub("", text).strip()[:1800]


def _lang(ctx: ChatContext, message: str) -> str:
    raw = (ctx.language or "").lower()
    if raw.startswith("fr"):
        return "fr"
    if raw.startswith("en"):
        if message and _FR_HINT.search(message) and len(message.split()) >= 3:
            return "fr"
        return "en"
    if message and _FR_HINT.search(message):
        return "fr"
    return "en"


def _msg(lang: str, en: str, fr: str) -> str:
    return fr if lang == "fr" else en


def _rate_limit(user_key: str, msg_hash: str, lang: str) -> str | None:
    now = time.time()
    b: dict[str, Any] = _buckets.get(user_key) or {}
    if not b or now > b["reset_at"]:
        b = {
            "count": 0,
            "reset_at": now + 60,
            "in_flight": False,
            "last_hash": "",
            "last_at": 0.0,
        }
        _buckets[user_key] = b
    if b["in_flight"]:
        return _msg(
            lang,
            "Please wait for the current reply to finish.",
            "Attendez la fin de la réponse en cours.",
        )
    if b["last_hash"] == msg_hash and now - b["last_at"] < 2.5:
        return _msg(
            lang,
            "That message was just sent.",
            "Ce message vient d’être envoyé.",
        )
    if b["count"] >= RATE_LIMIT_PER_MIN:
        return _msg(
            lang,
            "Too many requests. Try again in a minute.",
            "Trop de demandes. Réessayez dans une minute.",
        )
    b["count"] += 1
    b["in_flight"] = True
    b["last_hash"] = msg_hash
    b["last_at"] = now
    return None


def _ids_from_tool_json(name: str, content: str) -> tuple[list[str], list[str]]:
    fac: list[str] = []
    med: list[str] = []
    try:
        data = json.loads(content)
    except Exception:
        return fac, med
    if not isinstance(data, dict):
        return fac, med
    if name in ("search_facilities", "get_facility_detail"):
        rows = data.get("results")
        if data.get("facility_id"):
            rows = [data]
        if not isinstance(rows, list):
            rows = []
        for row in rows:
            if isinstance(row, dict) and row.get("facility_id"):
                fac.append(str(row["facility_id"]))
    if name == "search_medications":
        for row in data.get("results") or []:
            if isinstance(row, dict) and row.get("medication_id"):
                med.append(str(row["medication_id"]))
    return fac, med


def _openrouter(
    messages: list[dict[str, Any]], *, with_tools: bool
) -> dict[str, Any]:
    if not OPENROUTER_API_KEY:
        raise HTTPException(status_code=503, detail="AI is not configured.")
    payload: dict[str, Any] = {
        "model": OPENROUTER_MODEL,
        "messages": messages,
        "temperature": 0.35,
        "max_tokens": MAX_OUTPUT_TOKENS,
    }
    if with_tools:
        payload["tools"] = TOOLS
        payload["tool_choice"] = "auto"
    try:
        res = _http.post(
            "https://openrouter.ai/api/v1/chat/completions",
            headers={
                "Authorization": f"Bearer {OPENROUTER_API_KEY}",
                "Content-Type": "application/json",
                "HTTP-Referer": "https://navisante.app",
                "X-Title": "NaviSante Navi AI",
            },
            json=payload,
        )
    except httpx.TimeoutException as exc:
        logger.warning("OpenRouter timeout: %s", exc)
        raise HTTPException(status_code=504, detail="timeout") from exc
    except httpx.HTTPError as exc:
        logger.error("OpenRouter HTTP error: %s", exc)
        raise HTTPException(status_code=502, detail="gateway") from exc
    except Exception as exc:
        logger.exception("OpenRouter unexpected error: %s", exc)
        raise HTTPException(status_code=502, detail="unexpected") from exc
    if res.status_code == 401:
        logger.error("OpenRouter 401 Unauthorized - check OPENROUTER_API_KEY: %s", res.text)
        raise HTTPException(status_code=502, detail="llm_auth")
    if res.status_code == 402:
        logger.error("OpenRouter 402 Payment Required - check credits: %s", res.text)
        raise HTTPException(status_code=502, detail="llm_credits")
    if res.status_code == 429:
        logger.warning("OpenRouter 429 Rate Limit: %s", res.text)
        raise HTTPException(status_code=429, detail="llm_rate")
    if res.status_code >= 400:
        logger.error("OpenRouter error %s: %s", res.status_code, res.text)
        raise HTTPException(status_code=502, detail="llm_error")
    try:
        return res.json()
    except Exception as exc:
        logger.exception("Failed to parse OpenRouter JSON: %s", exc)
        raise HTTPException(status_code=502, detail="llm_error") from exc


def _fail_from_http(exc: HTTPException, lang: str) -> ChatResponse:
    if exc.status_code == 504:
        return ChatResponse(
            ok=False,
            error=_msg(
                lang,
                "That took too long. Please try a shorter question.",
                "La réponse a pris trop de temps. Essayez une question plus courte.",
            ),
        )
    if exc.status_code == 429:
        return ChatResponse(
            ok=False,
            error=_msg(
                lang,
                "Too many requests. Try again in a minute.",
                "Trop de demandes. Réessayez dans une minute.",
            ),
        )
    if exc.status_code == 503:
        return ChatResponse(
            ok=False,
            error=_msg(
                lang,
                "Navi AI is unavailable right now. Please try again later.",
                "Navi AI est indisponible pour le moment. Réessayez plus tard.",
            ),
        )
    return ChatResponse(
        ok=False,
        error=_msg(
            lang,
            "Couldn't reach Navi AI. Check your connection and try again.",
            "Impossible de joindre Navi AI. Vérifiez la connexion et réessayez.",
        ),
    )


logger = logging.getLogger("navisante_gateway")


@asynccontextmanager
async def _lifespan(_: FastAPI):
    logger.info(
        "NaviSanté AI Gateway started — model=%s configured=%s",
        OPENROUTER_MODEL,
        bool(OPENROUTER_API_KEY),
    )
    yield
    _http.close()


app = FastAPI(
    title="NaviSanté AI Gateway",
    version="1.2.0",
    lifespan=_lifespan,
    docs_url=None,
    redoc_url=None,
)
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_methods=["POST", "GET"],
    allow_headers=["*"],
)


@app.get("/")
@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "status": "ok",
        "service": "NaviSanté AI Gateway",
        "model": OPENROUTER_MODEL,
        "configured": bool(OPENROUTER_API_KEY),
    }


@app.post("/v1/chat", response_model=ChatResponse)
def chat(
    body: ChatRequest,
    x_gateway_secret: str | None = Header(default=None),
    x_user_id: str | None = Header(default=None),
) -> ChatResponse:
    if not GATEWAY_SECRET:
        raise HTTPException(status_code=503, detail="unconfigured")
    if x_gateway_secret != GATEWAY_SECRET:
        raise HTTPException(status_code=401, detail="unauthorized")

    message = (body.message or "").strip()
    follow_up = bool(body.tool_results)
    lang = _lang(body.context, message)
    if not message and not follow_up:
        return ChatResponse(
            ok=False,
            error=_msg(lang, "Please type a message.", "Écrivez un message."),
        )

    user_key = x_user_id or "anon"
    msg_hash = hashlib.sha256(
        f"{body.conversation_id}:{message.lower()}".encode()
    ).hexdigest()
    bucket = _buckets.get(user_key)
    if not follow_up:
        limited = _rate_limit(user_key, msg_hash, lang)
        bucket = _buckets.get(user_key)
        if limited:
            return ChatResponse(ok=False, error=limited)

    ctx = body.context
    names = ", ".join(ctx.bookmark_names[:6])
    context_line = (
        f"Live app state: country={ctx.country or 'Cameroon'}; "
        f"language={lang}; "
        f"coords={ctx.lat},{ctx.lng}; "
        f"saved_facilities={ctx.bookmark_count}"
        + (f" ({names})" if names else "")
        + ". GPS is already known — do not call a tool just to read it. "
        "Coverage is Cameroon-wide, not Yaoundé-only."
    )

    messages: list[dict[str, Any]] = [
        {"role": "system", "content": SYSTEM},
        {"role": "system", "content": context_line},
    ]
    for turn in body.history[-HISTORY_TURNS:]:
        if turn.role in ("user", "assistant") and turn.content:
            messages.append(
                {"role": turn.role, "content": turn.content[:HISTORY_CHARS]}
            )
    if message:
        messages.append({"role": "user", "content": message[:USER_CHARS]})

    facility_ids: list[str] = []
    medication_ids: list[str] = []

    if body.tool_results:
        assistant_calls = []
        for tr in body.tool_results[:MAX_TOOL_CALLS]:
            assistant_calls.append(
                {
                    "id": tr.tool_call_id,
                    "type": "function",
                    "function": {
                        "name": tr.name,
                        "arguments": tr.arguments or "{}",
                    },
                }
            )
            fids, mids = _ids_from_tool_json(tr.name, tr.content)
            for i in fids:
                if i not in facility_ids:
                    facility_ids.append(i)
            for i in mids:
                if i not in medication_ids:
                    medication_ids.append(i)
        messages.append(
            {
                "role": "assistant",
                "content": None,
                "tool_calls": assistant_calls,
            }
        )
        for tr in body.tool_results[:MAX_TOOL_CALLS]:
            messages.append(
                {
                    "role": "tool",
                    "tool_call_id": tr.tool_call_id,
                    "content": tr.content[:TOOL_CONTENT_CHARS],
                }
            )

    try:
        data = _openrouter(messages, with_tools=not follow_up)
        choice = (data.get("choices") or [{}])[0]
        msg = choice.get("message") or {}
        raw_calls = msg.get("tool_calls") or []
        if raw_calls and not follow_up:
            calls = [
                ToolCallOut(
                    id=c.get("id") or "",
                    name=(c.get("function") or {}).get("name") or "",
                    arguments=(c.get("function") or {}).get("arguments") or "{}",
                )
                for c in raw_calls[:MAX_TOOL_CALLS]
            ]
            return ChatResponse(ok=True, tool_calls=calls)
        text = _plain(msg.get("content") or "")
        fallback = _msg(
            lang,
            "I can help with NaviSanté facilities, medications, and general health questions.",
            "Je peux vous aider avec les établissements NaviSanté, les médicaments et des questions de santé générales.",
        )
        return ChatResponse(
            ok=True,
            text=text or fallback,
            facility_ids=facility_ids[:3],
            medication_ids=medication_ids[:3],
        )
    except HTTPException as exc:
        logger.warning("Chat request failed with HTTP %s: %s", exc.status_code, exc.detail)
        return _fail_from_http(exc, lang)
    except Exception as exc:
        logger.exception("Unexpected error handling chat request: %s", exc)
        return ChatResponse(
            ok=False,
            error=_msg(
                lang,
                "Couldn't reach Navi AI. Check your connection and try again.",
                "Impossible de joindre Navi AI. Vérifiez la connexion et réessayez.",
            ),
        )
    finally:
        if bucket is not None:
            bucket["in_flight"] = False
