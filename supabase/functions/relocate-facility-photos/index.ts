// supabase/functions/relocate-facility-photos/index.ts
//
// OPTIONAL add-on. The SQL migration works perfectly without this — it
// just means an approved ticket's photos stay physically in the temp
// bucket unless you've deployed this function.
//
// What it does: the instant a facility_suggestions row's status becomes
// 'approved' with a target_folder_url set, this downloads each photo from
// the temp bucket and re-uploads it into that facility's real folder in
// `healthFacility_images`, then deletes the temp copy. Fully automatic —
// you never touch a file.
//
// SETUP (one time):
//   1. supabase functions new relocate-facility-photos
//      (then replace its index.ts with this file's contents)
//   2. supabase functions deploy relocate-facility-photos
//   3. In the Supabase Dashboard → Database → Webhooks → Create a new
//      webhook:
//        - Table: facility_suggestions
//        - Events: Update
//        - Type: Supabase Edge Function
//        - Function: relocate-facility-photos
//      (The function checks status/target_folder_url itself below, so you
//      don't need to hand-configure a column filter in the webhook UI.)
//
// The function uses the service-role key (automatically available to
// every Edge Function as SUPABASE_SERVICE_ROLE_KEY) so it can read/write
// across both buckets regardless of the RLS policies that apply to
// regular users.

import { createClient } from "https://esm.sh/@supabase/supabase-js@2";

const TEMP_BUCKET = "facility_suggestion_photos";
const FINAL_BUCKET = "healthFacility_images";

const supabase = createClient(
  Deno.env.get("SUPABASE_URL")!,
  Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
);

function extractPath(url: string, bucket: string): string | null {
  const marker = `/object/public/${bucket}/`;
  const idx = url.indexOf(marker);
  return idx >= 0 ? url.slice(idx + marker.length) : null;
}

Deno.serve(async (req) => {
  const payload = await req.json();
  const record = payload?.record as
    | { status: string; target_folder_url: string | null; photo_urls: string[] }
    | undefined;

  if (!record || record.status !== "approved" || !record.target_folder_url) {
    return new Response("skipped — not an approval with a folder set", { status: 200 });
  }

  const folderPath = extractPath(record.target_folder_url, FINAL_BUCKET) ??
    record.target_folder_url.replace(/^\/+|\/+$/g, "") + "/";

  const results: string[] = [];

  for (const url of record.photo_urls ?? []) {
    const sourcePath = extractPath(url, TEMP_BUCKET);
    if (!sourcePath) continue; // not a temp-bucket url — leave it alone

    const filename = sourcePath.split("/").pop()!;
    const destPath = `${folderPath.replace(/\/+$/, "")}/${filename}`;

    const { data: fileData, error: downloadError } = await supabase.storage
      .from(TEMP_BUCKET)
      .download(sourcePath);

    if (downloadError || !fileData) {
      results.push(`FAILED download ${sourcePath}: ${downloadError?.message}`);
      continue;
    }

    const { error: uploadError } = await supabase.storage
      .from(FINAL_BUCKET)
      .upload(destPath, fileData, { upsert: true });

    if (uploadError) {
      results.push(`FAILED upload ${destPath}: ${uploadError.message}`);
      continue;
    }

    await supabase.storage.from(TEMP_BUCKET).remove([sourcePath]);
    results.push(`OK ${sourcePath} -> ${destPath}`);
  }

  return new Response(JSON.stringify({ results }), {
    headers: { "Content-Type": "application/json" },
  });
});