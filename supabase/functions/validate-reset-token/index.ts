import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

// VERCEL_ORIGIN = scheme + host only, no path, no trailing slash
// e.g. "https://navisante-password-reset-vercel.vercel.app"
// The browser Origin header never includes a path — if this has a path,
// every CORS preflight will fail with a mismatch.
const VERCEL_ORIGIN = Deno.env.get("VERCEL_ORIGIN")!;

const corsHeaders = {
  "Access-Control-Allow-Origin": VERCEL_ORIGIN,
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers": "content-type",
};

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;

// ── SHA-256 helper ─────────────────────────────────────────────────────────
async function sha256Hex(input: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  const hashArray = Array.from(new Uint8Array(hashBuffer));
  return hashArray.map((b) => b.toString(16).padStart(2, "0")).join("");
}

serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const json = (data: object, status = 200) =>
    new Response(JSON.stringify(data), {
      status,
      headers: { ...corsHeaders, "Content-Type": "application/json" },
    });

  try {
    const body = await req.json().catch(() => ({}));
    const rawToken = typeof body.token === "string" ? body.token.trim() : null;

    // Validate raw token format: must be 64 lowercase hex chars (32 bytes)
    if (!rawToken || !/^[0-9a-f]{64}$/.test(rawToken)) {
      return json({ valid: false, reason: "invalid_format" }, 400);
    }

    // ── Hash the incoming raw token ────────────────────────────────
    // DB stores SHA-256(rawToken). We hash before querying.
    // Attacker with DB access sees only hashes — useless without raw tokens.
    const tokenHash = await sha256Hex(rawToken);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // ── Query by hash, not raw token ───────────────────────────────
    const { data: record, error } = await supabase
      .from("reset_tokens")
      .select("id, email, expires_at, used_at")
      .eq("token", tokenHash)       // ← compare hash to hash
      .single();

    if (error || !record) {
      return json({ valid: false, reason: "not_found" });
    }

    if (record.used_at) {
      return json({ valid: false, reason: "already_used" });
    }

    if (new Date(record.expires_at) < new Date()) {
      // Clean up expired record
      await supabase.from("reset_tokens").delete().eq("token", tokenHash);
      return json({ valid: false, reason: "expired" });
    }

    return json({ valid: true });

  } catch (err) {
    console.error("[EF2] Unexpected error:", err);
    return json({ valid: false, reason: "server_error" }, 500);
  }
});