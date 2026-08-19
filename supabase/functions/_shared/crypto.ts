// SHA-256 token hashing function before database storage. 
// Only the hash is stored and sent in the email never the real token.
export async function sha256Hex(input: string): Promise<string> {
  const encoder = new TextEncoder();
  const data = encoder.encode(input);
  const hashBuffer = await crypto.subtle.digest("SHA-256", data);
  return Array.from(new Uint8Array(hashBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Token generation helper 32 random bytes (256 bits).
// Crypto.getRandomValues is a CSPRNG (cryptographically secure).
export function generateRawToken(): string {
  const bytes = new Uint8Array(32);
  crypto.getRandomValues(bytes);
  return Array.from(bytes)
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}

// Token REGEX
// Shared so EF2 and EF3 can't drift on what counts as a valid shape.
export const TOKEN_FORMAT = /^[0-9a-f]{64}$/;

// HMAC SHA-256 signature generator for tamper-proof URL expiration timestamps
export async function createHmacSha256(
  keySecret: string,
  message: string
): Promise<string> {
  const encoder = new TextEncoder();
  const keyData = encoder.encode(keySecret);
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    keyData,
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"]
  );
  const signatureBuffer = await crypto.subtle.sign(
    "HMAC",
    cryptoKey,
    encoder.encode(message)
  );
  return Array.from(new Uint8Array(signatureBuffer))
    .map((b) => b.toString(16).padStart(2, "0"))
    .join("");
}
