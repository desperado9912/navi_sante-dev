import { createHmacSha256, TOKEN_FORMAT } from "../_shared/crypto.ts";

const VERCEL_RESET_URL = Deno.env.get("VERCEL_RESET_URL")!;
const LINK_SIGNING_SECRET =
  Deno.env.get("LINK_SIGNING_SECRET") ?? "fallback-secret-change-in-prod";

function render410Page(): Response {
  const html = `
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <meta name="viewport" content="width=device-width, initial-scale=1.0">
      <title>410 Link Expired</title>
      <style>
        body {
          font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif;
          background-color: #0f172a;
          color: #f8fafc;
          display: flex;
          align-items: center;
          justify-content: center;
          height: 100vh;
          margin: 0;
        }
        .card {
          background-color: #1e293b;
          border: 1px solid #334155;
          padding: 2.5rem;
          border-radius: 12px;
          text-align: center;
          max-width: 420px;
          box-shadow: 0 10px 25px rgba(0,0,0,0.3);
        }
        h1 { color: #f43f5e; margin-top: 0; font-size: 1.5rem; font-weight: 700; }
        p { color: #94a3b8; line-height: 1.6; font-size: 0.95rem; margin-bottom: 0; }
      </style>
    </head>
    <body>
      <div class="card">
        <h1>410 - Link Expired</h1>
        <p>This password reset link has expired after 24 hours and is no longer valid. Please request a new password reset link from the NaviSanté app.</p>
      </div>
    </body>
    </html>
  `;

  return new Response(html, {
    status: 410,
    headers: { "Content-Type": "text/html; charset=utf-8" },
  });
}

Deno.serve(async (req: Request) => {
  const url = new URL(req.url);
  const token = url.searchParams.get("token")?.trim() ?? "";
  const exp = url.searchParams.get("exp")?.trim() ?? "";
  const sig = url.searchParams.get("sig")?.trim() ?? "";

  // 1. Check parameter presence & format
  if (!token || !exp || !sig || !TOKEN_FORMAT.test(token)) {
    return render410Page();
  }

  // 2. Verify HMAC Signature (prevents URL tampering)
  const expectedSig = await createHmacSha256(LINK_SIGNING_SECRET, `${token}:${exp}`);
  if (sig !== expectedSig) {
    return render410Page();
  }

  // 3. Verify 24-Hour Expiration
  const expiryTimestamp = parseInt(exp, 10);
  if (isNaN(expiryTimestamp) || Date.now() > expiryTimestamp) {
    return render410Page();
  }

  // 4. Valid & Under 24 Hours -> HTTP 302 Redirect to React SPA
  return Response.redirect(`${VERCEL_RESET_URL}?token=${token}`, 302);
});
