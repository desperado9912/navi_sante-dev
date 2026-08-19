import type { SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2";

interface RateLimitCheck {
  supabase: SupabaseClient;
  eventType: string;
  field: "ip_address" | "email";
  value: string | null;
  windowMs: number;
  maxCount: number;
}

// Returns true if the caller has hit the limit and should be blocked.
//
// Backed by security_logs rather than reset_tokens deliberately —
// reset_tokens rows get deleted (on success, on expiry cleanup), so
// they're not a reliable window to count against. security_logs is
// meant to be a permanent audit trail, so counting against it doesn't
// silently reset itself.
export async function isRateLimited({
  supabase,
  eventType,
  field,
  value,
  windowMs,
  maxCount,
}: RateLimitCheck): Promise<boolean> {
  if (!value) return false; // nothing to key on — don't block over it

  const since = new Date(Date.now() - windowMs).toISOString();

  const { count, error } = await supabase
    .from("security_logs")
    .select("id", { count: "exact", head: true })
    .eq("event_type", eventType)
    .eq(field, value)
    .gte("created_at", since);

  if (error) {
    // Fail OPEN, not closed: if the rate-limit check itself breaks,
    // that shouldn't block a legitimate user. Rate limiting is a cost/
    // abuse-hygiene layer here, not the core security boundary — that's
    // the token's 256-bit entropy and the atomic single-use claim in
    // EF3, neither of which depend on this check succeeding.
    console.error(`[rateLimit] check failed for ${eventType}:`, error.message);
    return false;
  }

  return (count ?? 0) >= maxCount;
}