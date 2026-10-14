// Called by the app (Settings → Delete my account). Right to erasure (GDPR art. 17):
// removes the user's photos, then the auth user. The database then deletes the
// profile, walks and confirmations, and detaches reports (note and photo path erased),
// keeping only anonymous category/place/time so zone counts stay honest.
import { adminClient, json } from "../_shared/server.ts";

Deno.serve(async (request) => {
  if (request.method !== "POST") return json({ error: "method not allowed" }, 405);
  const jwt = (request.headers.get("Authorization") ?? "").replace(/^Bearer\s+/i, "");
  const supabase = adminClient();
  const { data: userData, error: userError } = await supabase.auth.getUser(jwt);
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);
  const userID = userData.user.id;

  const bucket = supabase.storage.from("report-photos");
  for (;;) {
    const { data: files, error } = await bucket.list(userID, { limit: 100 });
    if (error) return json({ error: error.message }, 500);
    if (!files?.length) break;
    const { error: removeError } = await bucket.remove(files.map((file) => `${userID}/${file.name}`));
    if (removeError) return json({ error: removeError.message }, 500);
    if (files.length < 100) break;
  }

  const { error } = await supabase.auth.admin.deleteUser(userID);
  if (error) return json({ error: error.message }, 500);
  return json({ deleted: true });
});
