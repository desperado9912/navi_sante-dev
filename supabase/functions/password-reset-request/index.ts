// EDGE FUNCTION 1
import { createServiceClient } from "../_shared/supabase.ts";
import { sha256Hex, generateRawToken } from "../_shared/crypto.ts";
import { buildCorsHeaders } from "../_shared/cors.ts";
import { isRateLimited } from "../_shared/rateLimit.ts";

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

// EF1 is only ever called from the Flutter app.
const corsHeaders = buildCorsHeaders("*");

const VERCEL_RESET_URL = Deno.env.get("VERCEL_RESET_URL")!;
const RESEND_API_KEY = Deno.env.get("RESEND_API_KEY")!;
// Swap this once you've verified your own domain in Resend — until
// then, onboarding@resend.dev works with zero setup.
const RESET_EMAIL_FROM =
  Deno.env.get("RESET_EMAIL_FROM") ?? "NaviSanté <onboarding@resend.dev>";

const EMAIL_REGEX = /^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$/;
const TOKEN_TTL_MS = 30 * 60 * 1000; // 30 minutes

function buildResetEmailHtml(resetLink: string): string {
  // Plain, self-contained HTML — no external stylesheet.
  return `
    <div style="font-family: 'Plus Jakarta Sans' -apple-system, sans-serif; max-width: 480px; margin: 0 auto; color: #0f172a;">
      <h2 style="margin-bottom: 8px;">Reset your password</h2>
      <p style="color: #1A1A1A; line-height: 1.5;">
        This is a request to reset your NaviSanté account password.
        Please click the link below and follow the steps to set a new password.
        <strong style="font-weight: 600;">This link expires in 30 minutes and can only be used once.</strong>
      </p>
      <p style="margin: 24px 0;">
        <a href="${resetLink}"
           style="display:inline-block;padding:12px 24px;background:#2A7D8F;
                  color:#ffffff;text-decoration:none;border-radius:8px;
                  font-weight:600;">
          Reset Password
        </a>
      </p>
      <p style="color: #5F6368; font-size: 13px; line-height: 1.5;">
        If you didn't request this, you can safely ignore this email. 
        Your password will not be changed.
      </p>
    </div>
  `;
}

// Returns true on success. Never throws — a failed send is handled by
// the caller (which cleans up the orphaned token record).
async function sendResetEmail(toEmail: string, resetLink: string): Promise<boolean> {
  try {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${RESEND_API_KEY}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: RESET_EMAIL_FROM,
        to: toEmail,
        subject: "NaviSanté Password Reset",
        html: buildResetEmailHtml(resetLink),
      }),
    });

    if (!response.ok) {
      console.error("[EF1] Resend API error:", response.status, await response.text());
      return false;
    }
    return true;
  } catch (err) {
    console.error("[EF1] Email send threw:", err);
    return false;
  }
}

Deno.serve(async (req: Request) => {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }

  // Always the identical response, whatever happened internally — never
  // reveals whether an email is registered, rate-limited, malformed, or
  // failed to send. This is the anti-enumeration guarantee.
  const genericSuccess = () => jsonResponse({ success: true }, corsHeaders);

  try {
    const body = await req.json().catch(() => ({}));
    const email =
      typeof body.email === "string" ? body.email.trim().toLowerCase() : null;

    const ipAddress =
      req.headers.get("cf-connecting-ip") ??
      req.headers.get("x-forwarded-for") ??
      null;

    if (!email || !EMAIL_REGEX.test(email)) {
      return genericSuccess();
    }

    const supabase = createServiceClient();

    // ── Rate limit #1: this specific email ──────────────────────────
    const emailLimited = await isRateLimited({
      supabase,
      eventType: "password_reset_requested",
      field: "email",
      value: email,
      windowMs: 2 * 60 * 1000, // 2 minutes
      maxCount: 1,
    });
    if (emailLimited) return genericSuccess();

    // ── Rate limit #2: this IP address ───────────────────────────────
    // The per-email limit alone doesn't stop one source from targeting
    // many DIFFERENT inboxes in a short window — this catches that.
    if (ipAddress) {
      const ipLimited = await isRateLimited({
        supabase,
        eventType: "password_reset_requested",
        field: "ip_address",
        value: ipAddress,
        windowMs: 60 * 60 * 1000, // 1 hour
        maxCount: 5,
      });
      if (ipLimited) return genericSuccess();
    }

    // ── Generate + hash the token ─────────────────────────────────────
    // Raw token goes in the email only, never logged, never stored.
    // Only its SHA-256 hash is written to the database.
    const rawToken = generateRawToken();
    const tokenHash = await sha256Hex(rawToken);
    const expiresAt = new Date(Date.now() + TOKEN_TTL_MS).toISOString();

    const { error: insertError } = await supabase.from("reset_tokens").insert({
      token: tokenHash,
      email,
      expires_at: expiresAt,
      ip_address: ipAddress,
    });

    if (insertError) {
      console.error("[EF1] Insert failed:", insertError.message);
      return genericSuccess();
    }

    // ── Send the email ────────────────────────────────────────────────
    // Deliberately NOT using supabase.auth.resetPasswordForEmail() —
    // that call embeds a live Supabase session into the redirect URL,
    // which would let the frontend bypass this entire token system.
    // This sends a plain email we fully control instead.
    const resetLink = `${VERCEL_RESET_URL}?token=${rawToken}`;
    const emailSent = await sendResetEmail(email, resetLink);

    if (!emailSent) {
      // No point leaving a token nobody can ever use.
      await supabase.from("reset_tokens").delete().eq("token", tokenHash);
      console.error("[EF1] Email send failed for", email, "— token discarded.");
      return genericSuccess(); // still anti-enumeration — don't reveal failure
    }

    // ── Log the request ────────────────────────────────────────────────
    // This insert is also what the two rate-limit checks above count
    // against on the NEXT request.
    const { error: logError } = await supabase.from("security_logs").insert({
      event_type: "password_reset_requested",
      email,
      ip_address: ipAddress,
      metadata: {},
    });
    if (logError) {
      console.error("[EF1] Security log failed:", logError.message);
    }

    return genericSuccess();
  } catch (err) {
    console.error("[EF1] Unexpected error:", err);
    return genericSuccess();
  }
});