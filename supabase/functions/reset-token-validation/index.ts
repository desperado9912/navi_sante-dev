// EDGE FUNCTION 2
import { createServiceClient } from "../_shared/supabase.ts";
import { sha256Hex, TOKEN_FORMAT } from "../_shared/crypto.ts";
import { buildCorsHeaders } from "../_shared/cors.ts";

function jsonResponse(
  data: object,
  corsHeaders: Record<string, string>,
  status = 200
): Response {
  return new Response(JSON.stringify(data), {
    status,
    headers: { ...corsHeaders, "Content-Type": "application/json" },
  });
}

// Called directly from the browser (the Vercel reset page's fetch
// calls) — origin-restricted, unlike EF1 which is only ever called
// from the Flutter app.
const VERCEL_ORIGIN = Deno.env.get("VERCEL_ORIGIN")!;
const corsHeaders = buildCorsHeaders(VERCEL_ORIGIN);

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Always HTTP 200 — this endpoint reports token status IN the JSON
  // body, not via status code. An invalid/expired token isn't a server
  // error, so it shouldn't look like one to the frontend's fetch call.
  const respond = (data: object) => jsonResponse(data, corsHeaders, 200);

  try {
    const body = await req.json().catch(() => ({}));
    const rawToken = typeof body.token === "string" ? body.token.trim() : "";

    if (!TOKEN_FORMAT.test(rawToken)) {
      return respond({ valid: false, reason: "invalid_format" });
    }

    // Hash before querying — the DB only ever stores/compares hashes,
    // never the raw token. Even with full DB access, an attacker can't
    // reverse a hash back into a usable token.
    const tokenHash = await sha256Hex(rawToken);
    const supabase = createServiceClient();

    // maybeSingle(), not single(): single() throws an error for BOTH
    // "zero rows found" (normal — token doesn't exist) AND a genuine
    // query failure, making them indistinguishable. That matters here
    // because the frontend treats them differently — "not_found" is a
    // definitive verdict (show Expired), "server_error" means "retry"
    // (transient failure, don't tell the user their link is dead).
    // maybeSingle() returns { data: null, error: null } for zero rows,
    // so the two cases stay separable below.
    const { data: record, error } = await supabase
      .from("reset_tokens")
      .select("email, expires_at, used_at")
      .eq("token", tokenHash)
      .maybeSingle();

    if (error) {
      console.error("[EF2] Lookup failed:", error.message);
      return respond({ valid: false, reason: "server_error" });
    }

    if (!record) {
      return respond({ valid: false, reason: "not_found" });
    }

    if (record.used_at) {
      return respond({ valid: false, reason: "already_used" });
    }

    if (new Date(record.expires_at) < new Date()) {
      // Best-effort cleanup, not required for correctness — the checks
      // above already make this row inert regardless. Just keeps the
      // table smaller between the nightly cron cleanup.
      await supabase.from("reset_tokens").delete().eq("token", tokenHash);
      return respond({ valid: false, reason: "expired" });
    }

    // Required: the reset link only carries the token, not the email.
    // EF3 needs the email, and the only place the frontend can get it
    // from is this response — omitting it breaks the whole flow at the
    // form-submission step.
    return respond({ valid: true, email: record.email });
  } catch (err) {
    console.error("[EF2] Unexpected error:", err);
    return respond({ valid: false, reason: "server_error" });
  }
});