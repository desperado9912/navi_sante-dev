import { serve } from "https://deno.land/std@0.168.0/http/server.ts";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

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
    const { token, email, new_password } = body;

    // ── Input presence check ───────────────────────────────────────
    if (!token || !email || !new_password) {
      return json({ success: false, error: "Missing required fields." }, 400);
    }

    // ── Raw token format validation ────────────────────────────────
    if (typeof token !== "string" || !/^[0-9a-f]{64}$/.test(token)) {
      return json({ success: false, error: "Invalid reset link." }, 400);
    }

    const normalizedEmail =
      typeof email === "string" ? email.trim().toLowerCase() : "";
    if (!normalizedEmail) {
      return json({ success: false, error: "Invalid email address." }, 400);
    }

    // ── Server-side password validation ────────────────────────────
    // Mirrors client-side rules — never trust client-only validation.
    if (typeof new_password !== "string" || new_password.length < 8) {
      return json(
        { success: false, error: "Password must be at least 8 characters." },
        400
      );
    }
    if (!/[A-Z]/.test(new_password)) {
      return json(
        {
          success: false,
          error: "Password must contain at least one uppercase letter.",
        },
        400
      );
    }
    if (!/[0-9]/.test(new_password)) {
      return json(
        { success: false, error: "Password must contain at least one number." },
        400
      );
    }

    // ── Hash the incoming raw token ────────────────────────────────
    const tokenHash = await sha256Hex(token);

    const supabase = createClient(SUPABASE_URL, SERVICE_ROLE_KEY, {
      auth: { persistSession: false },
    });

    // ── Re-validate token by hash (critical second check) ─────────
    const { data: record, error: fetchError } = await supabase
      .from("reset_tokens")
      .select("id, email, expires_at, used_at")
      .eq("token", tokenHash)       // ← hash comparison
      .single();

    if (fetchError || !record) {
      return json(
        { success: false, error: "Invalid reset link. Please request a new one." },
        401
      );
    }

    if (record.used_at) {
      return json(
        { success: false, error: "This reset link has already been used." },
        401
      );
    }

    if (new Date(record.expires_at) < new Date()) {
      await supabase.from("reset_tokens").delete().eq("token", tokenHash);
      return json(
        {
          success: false,
          error: "This reset link has expired. Please request a new one.",
        },
        401
      );
    }

    // ── Email second verification factor ───────────────────────────
    if (record.email !== normalizedEmail) {
      await supabase
        .from("security_logs")
        .insert({
          event_type: "password_reset_email_mismatch",
          email: normalizedEmail,
          metadata: { token_email: record.email },
        })
        .catch(console.error);

      return json(
        {
          success: false,
          error: "The email address does not match our records.",
        },
        401
      );
    }

    // ── Atomic single-use claim ────────────────────────────────────
    // Only succeeds if used_at IS NULL — blocks race conditions where
    // two simultaneous requests attempt to use the same token.
    const { data: claimed, error: claimError } = await supabase
      .from("reset_tokens")
      .update({ used_at: new Date().toISOString() })
      .eq("token", tokenHash)
      .is("used_at", null)           // Atomic guard
      .select("id");

    if (claimError || !claimed || claimed.length === 0) {
      return json(
        { success: false, error: "This reset link has already been used." },
        401
      );
    }

    // ── Resolve user ID by email ───────────────────────────────────
    const { data: userId, error: rpcError } = await supabase.rpc(
      "get_user_id_by_email",
      { email_input: normalizedEmail }
    );

    if (rpcError || !userId) {
      // Un-mark the token — user can retry
      await supabase
        .from("reset_tokens")
        .update({ used_at: null })
        .eq("token", tokenHash);

      return json(
        { success: false, error: "No account found with this email address." },
        404
      );
    }

    // ── Update password via admin API ─────────────────────────────
    const { error: updateError } = await supabase.auth.admin.updateUserById(
      userId,
      { password: new_password }
    );

    if (updateError) {
      // Password update failed — un-mark token so user can retry
      await supabase
        .from("reset_tokens")
        .update({ used_at: null })
        .eq("token", tokenHash);

      console.error("[EF3] Admin password update failed:", updateError.message);
      return json(
        { success: false, error: "Failed to update password. Please try again." },
        500
      );
    }

    // ── Destroy token immediately ──────────────────────────────────
    await supabase.from("reset_tokens").delete().eq("token", tokenHash);

   // ── Log success ───────────────────────────────────────────────
    try {
      await supabase
        .from("security_logs")
        .insert({
          event_type: "password_reset_success",
          user_id: userId,
          email: normalizedEmail,
          metadata: { sessions_revoked: "automatic_on_password_change" },
        });
    } catch (logError) {
      console.error("[EF3] Security log insertion failed:", logError);
    }

    return json({ success: true });

    } catch (err) {
    console.error("[EF3] Unexpected error:", err);
    return json({ success: false, error: "An unexpected error occurred." }, 500);
  }
});