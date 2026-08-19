// EDGE FUNCTION 3
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

const VERCEL_ORIGIN = Deno.env.get("VERCEL_ORIGIN")!;
const corsHeaders = buildCorsHeaders(VERCEL_ORIGIN);

type ServiceClient = ReturnType<typeof createServiceClient>;

async function logSecurityEvent(
  supabase: ServiceClient,
  eventType: string,
  email: string,
  metadata: Record<string, unknown> = {}
) {
  const { error } = await supabase
    .from("security_logs")
    .insert({ event_type: eventType, email, metadata });
  if (error) {
    console.error(`[EF3] Failed to log ${eventType}:`, error.message);
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  const respond = (data: object, status = 200) =>
    jsonResponse(data, corsHeaders, status);

  try {
    const body = await req.json().catch(() => ({}));
    const { token, email, new_password } = body;

    // ── Input presence ──────────────────────────────────────────────
    if (!token || !email || !new_password) {
      return respond({ success: false, error: "Missing required fields." }, 400);
    }

    if (typeof token !== "string" || !TOKEN_FORMAT.test(token)) {
      return respond({ success: false, error: "Invalid reset link." }, 400);
    }

    const normalizedEmail =
      typeof email === "string" ? email.trim().toLowerCase() : "";
    if (!normalizedEmail) {
      return respond({ success: false, error: "Invalid email address." }, 400);
    }

    // ── Server-side password rules ──────────────────────────────────
    // MUST stay in sync by hand with src/utils/passwordValidation.ts
    // on the frontend — there's no shared package between the Deno
    // and Vite projects to enforce this automatically.
    if (typeof new_password !== "string" || new_password.length < 8) {
      return respond(
        { success: false, error: "Password must be at least 8 characters." },
        400
      );
    }
    if (!/[A-Z]/.test(new_password)) {
      return respond(
        { success: false, error: "Password must contain at least one uppercase letter." },
        400
      );
    }
    if (!/[0-9]/.test(new_password)) {
      return respond(
        { success: false, error: "Password must contain at least one number." },
        400
      );
    }

    const tokenHash = await sha256Hex(token);
    const supabase = createServiceClient();

    // ── Re-validate independently of EF2 ────────────────────────────
    // This function never trusts that EF2 was called first, or that
    // its answer is still current — the frontend's pre-submit reverify
    // is a UX nicety, not something this function relies on. Every
    // check below runs fresh, right before the password actually
    // changes. maybeSingle() for the same reason as EF2 — see there.
    const { data: record, error: fetchError } = await supabase
      .from("reset_tokens")
      .select("id, email, expires_at, used_at")
      .eq("token", tokenHash)
      .maybeSingle();

    if (fetchError) {
      console.error("[EF3] Lookup failed:", fetchError.message);
      return respond(
        { success: false, error: "Something went wrong. Please try again." },
        500
      );
    }

    if (!record) {
      return respond(
        { success: false, error: "Invalid reset link. Please request a new one." },
        401
      );
    }

    if (record.used_at) {
      // Logged (new): repeated reuse attempts against a spent token
      // are worth visibility, same as the mismatch case below already
      // was — e.g. two tabs racing, or a link shared/reused later.
      await logSecurityEvent(supabase, "password_reset_reuse_attempt", normalizedEmail);
      return respond(
        { success: false, error: "This reset link has already been used." },
        401
      );
    }

    if (new Date(record.expires_at) < new Date()) {
      await supabase.from("reset_tokens").delete().eq("token", tokenHash);
      return respond(
        { success: false, error: "This reset link has expired. Please request a new one." },
        401
      );
    }

    // ── Email as a second verification factor ───────────────────────
    if (record.email !== normalizedEmail) {
      await logSecurityEvent(supabase, "password_reset_email_mismatch", normalizedEmail, {
        token_email: record.email,
      });
      return respond(
        { success: false, error: "The email address does not match our records." },
        401
      );
    }

    // ── Atomic single-use claim ──────────────────────────────────────
    // Succeeds only if used_at IS currently NULL. This is what makes
    // two concurrent requests for the same token (e.g. two open tabs)
    // safe — only one UPDATE can win the race; the loser sees zero
    // rows affected below and is rejected, even though both requests
    // passed every check above.
    const { data: claimed, error: claimError } = await supabase
      .from("reset_tokens")
      .update({ used_at: new Date().toISOString() })
      .eq("token", tokenHash)
      .is("used_at", null)
      .select("id");

    if (claimError || !claimed || claimed.length === 0) {
      return respond(
        { success: false, error: "This reset link has already been used." },
        401
      );
    }

    // ── Resolve the user ID ──────────────────────────────────────────
    // Locked down via SQL migration: only service_role (this function)
    // can call this RPC — see the migration for why that matters.
    const { data: userId, error: rpcError } = await supabase.rpc(
      "get_user_id_by_email",
      { email_input: normalizedEmail }
    );

    if (rpcError || !userId) {
      // Un-claim the token so a subsequent attempt isn't blocked by
      // this one's failure — the token itself is still legitimately
      // valid, only this specific lookup failed.
      await supabase.from("reset_tokens").update({ used_at: null }).eq("token", tokenHash);
      return respond(
        { success: false, error: "No account found with this email address." },
        404
      );
    }

    // ── Update the password ──────────────────────────────────────────
    const { error: updateError } = await supabase.auth.admin.updateUserById(userId, {
      password: new_password,
    });

    if (updateError) {
      await supabase.from("reset_tokens").update({ used_at: null }).eq("token", tokenHash);
      console.error("[EF3] Password update failed:", updateError.message);
      return respond(
        { success: false, error: "Failed to update password. Please try again." },
        500
      );
    }

    // ── Destroy the token — only now, after full success ─────────────
    await supabase.from("reset_tokens").delete().eq("token", tokenHash);

    await logSecurityEvent(supabase, "password_reset_success", normalizedEmail, {
      user_id: userId,
    });

    return respond({ success: true });
  } catch (err) {
    console.error("[EF3] Unexpected error:", err);
    return respond({ success: false, error: "An unexpected error occurred." }, 500);
  }
});