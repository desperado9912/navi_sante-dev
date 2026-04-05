import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
  "Access-Control-Allow-Headers":
    "authorization, x-client-info, apikey, content-type",
};

const SUPABASE_URL     = Deno.env.get("SUPABASE_URL")!;
const SERVICE_ROLE_KEY = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!;
const VERCEL_RESET_URL = Deno.env.get("VERCEL_RESET_URL")!;

// ── SHA-256 helper ─────────────────────────────────────────────────────────
// Deno's Web Crypto API is available globally — no import needed.
// Returns lowercase hex string of the SHA-256 digest.
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

  // Always return generic success — never reveal if email exists (anti-enumeration)
  const successResponse = new Response(
    JSON.stringify({ success: true }),
    { headers: { ...corsHeaders, "Content-Type": "application/json" } }
  );

  try {
    const body = await req.json().catch(() => ({}));
    const email =
      typeof body.email === "string"
        ? body.email.trim().toLowerCase()
        : null;

    const emailRegex = /^[a-zA-Z0-9._%+\-]+@[a-zA-Z0-9.\-]+\.[a-zA-Z]{2,}$/;
    if (!email || !emailRegex.test(email)) {
      return successResponse;
    }

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // ── Rate limit: 1 request per email per 2 minutes ──────────────
    const twoMinutesAgo = new Date(Date.now() - 2 * 60 * 1000).toISOString();
    const { data: recentTokens } = await supabase
      .from("reset_tokens")
      .select("id")
      .eq("email", email)
      .gte("created_at", twoMinutesAgo)
      .limit(1);

    if (recentTokens && recentTokens.length > 0) {
      return successResponse; // Rate limited — silent
    }

    // ── Generate raw token (32 bytes = 256-bit entropy) ────────────
    // This is what goes into the email link — never stored.
    const rawTokenBytes = new Uint8Array(32);
    crypto.getRandomValues(rawTokenBytes);
    const rawToken = Array.from(rawTokenBytes)
      .map((b) => b.toString(16).padStart(2, "0"))
      .join("");

    // ── Hash the token before storing ─────────────────────────────
    // SHA-256(rawToken) is stored in the DB.
    // If the DB is ever compromised, hashes cannot be reversed to raw tokens.
    const tokenHash = await sha256Hex(rawToken);

    // ── Store the HASH (not the raw token) ────────────────────────
    const expiresAt = new Date(Date.now() + 30 * 60 * 1000).toISOString();
    const ipAddress =
      req.headers.get("cf-connecting-ip") ??
      req.headers.get("x-forwarded-for") ??
      null;

    const { error: insertError } = await supabase
      .from("reset_tokens")
      .insert({
        token: tokenHash,   // ← SHA-256 hash stored, NOT the raw token
        email,
        expires_at: expiresAt,
        ip_address: ipAddress,
      });

    if (insertError) {
      console.error("[EF1] DB insert failed:", insertError.message);
      return successResponse;
    }

    // ── Send email with the RAW token in the link ──────────────────
    // The raw token appears only in the email — never in any log or DB.
    const redirectTo = `${VERCEL_RESET_URL}?token=${rawToken}`;
    const { error: emailError } = await supabase.auth.resetPasswordForEmail(
      email,
      { redirectTo }
    );

    if (emailError) {
      // Clean up the hash record — email failed to send
      await supabase.from("reset_tokens").delete().eq("token", tokenHash);
      console.error("[EF1] Email send failed:", emailError.message);
      return successResponse; // Still return success — anti-enumeration
    }

    // ── Security log ──────────────────────────────────────────────
    await supabase
      .from("security_logs")
      .insert({
        event_type: "password_reset_requested",
        email,
        ip_address: ipAddress,
        metadata: { rate_limited: false },
      })
      .catch((err: Error) =>
        console.error("[EF1] Security log failed:", err.message)
      );

    return successResponse;

  } catch (err) {
    console.error("[EF1] Unexpected error:", err);
    return successResponse;
  }
});