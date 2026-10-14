// Daily (pg_cron): data minimisation (spec §8, "durée de conservation limitée").
//  * walk sessions are deleted 24 h after they end;
//  * reports older than retention_months lose author, note and photo.
import { adminClient, isServiceCall, json } from "../_shared/server.ts";

Deno.serve(async (request) => {
  if (!isServiceCall(request)) return json({ error: "forbidden" }, 403);
  const supabase = adminClient();

  const { data: purgedWalks, error: walkError } = await supabase.rpc("purge_walks");
  if (walkError) return json({ error: walkError.message }, 500);

  const { data: due, error: dueError } = await supabase.rpc("reports_to_anonymise");
  if (dueError) return json({ error: dueError.message }, 500);
  const rows = (due ?? []) as { id: string; photo_path: string | null }[];

  // Photos first: storage objects cannot be deleted from SQL.
  const paths = rows.map((row) => row.photo_path).filter((path): path is string => Boolean(path));
  if (paths.length) {
    const { error } = await supabase.storage.from("report-photos").remove(paths);
    if (error) return json({ error: error.message }, 500);
  }
  const { data: anonymised, error } = await supabase.rpc("anonymise_reports", { p_ids: rows.map((row) => row.id) });
  if (error) return json({ error: error.message }, 500);

  return json({ purgedWalks, anonymised });
});
