// Every 5 minutes (pg_cron): send confirmed road/cleanliness reports to the
// responsible service (spec §6). Theft, aggression and harassment never enter the
// outbox (no routing rule), so they can never be sent here.
//
// ROUTING_EMAILS maps destinations to addresses, optionally per commune:
//   {"bruxelles_proprete": "...", "commune": "...", "commune:21009": "..."}
// Destinations without an address stay queued (status "confirmed" in the app).
import { adminClient, isServiceCall, json, sendEmail } from "../_shared/server.ts";
import { categoryNames } from "../_shared/i18n.ts";

interface QueueItem {
  id: number;
  destination: string;
  attempts: number;
  reports: {
    id: string;
    category: string;
    created_at: string;
    occurred_at: string;
    note: string | null;
    photo_path: string | null;
    commune_code: string | null;
    status: string;
  } | null;
}

Deno.serve(async (request) => {
  if (!isServiceCall(request)) return json({ error: "forbidden" }, 403);
  const supabase = adminClient();
  const routing: Record<string, string> = JSON.parse(Deno.env.get("ROUTING_EMAILS") ?? "{}");

  const { data, error } = await supabase
    .from("outbox")
    .select("id, destination, attempts, reports(id, category, created_at, occurred_at, note, photo_path, commune_code, status)")
    .is("sent_at", null)
    .lt("attempts", 5)
    .order("created_at")
    .limit(50);
  if (error) return json({ error: error.message }, 500);

  let sent = 0;
  for (const item of (data ?? []) as unknown as QueueItem[]) {
    const report = item.reports;
    if (!report || report.status !== "confirmed") continue;
    const to = (report.commune_code && routing[`${item.destination}:${report.commune_code}`]) ?? routing[item.destination];
    if (!to) {
      await supabase.rpc("mark_dispatched", { p_outbox_id: item.id, p_error: "no address configured" });
      continue;
    }

    // Exact position for the service (it has to find the pothole). Coordinates come from
    // the service-role view of the report; never published anywhere else.
    const { data: point } = await supabase.rpc("report_point_for_service", { p_report_id: report.id });
    let photoLink = "";
    if (report.photo_path) {
      const { data: signed } = await supabase.storage.from("report-photos").createSignedUrl(report.photo_path, 7 * 24 * 3600);
      photoLink = signed?.signedUrl ?? "";
    }
    const name = categoryNames[report.category] ?? { fr: report.category, nl: report.category };
    const where = point ? `https://www.openstreetmap.org/?mlat=${point.lat}&mlon=${point.lon}#map=19/${point.lat}/${point.lon}` : "";
    const text = [
      `Signalement citoyen confirmé · Bevestigde burgermelding`,
      ``,
      `Type : ${name.fr} / ${name.nl}`,
      `Constaté le · Vastgesteld op : ${new Date(report.occurred_at).toLocaleString("fr-BE", { timeZone: "Europe/Brussels" })}`,
      `Lieu · Plaats : ${where}`,
      report.note ? `Note · Notitie : ${report.note}` : "",
      photoLink ? `Photo (floutée, lien valable 7 jours) · Foto (vervaagd, link 7 dagen geldig) : ${photoLink}` : "",
      ``,
      `Référence · Referentie : ${report.id}`,
      `Confirmé par plusieurs habitant·es via Brusk. Aucune donnée personnelle n'est transmise.`,
      `Bevestigd door meerdere bewoners via Brusk. Er worden geen persoonsgegevens doorgegeven.`,
    ].filter(Boolean).join("\n");

    try {
      await sendEmail({ to, subject: `Brusk · ${name.fr} / ${name.nl}`, text });
      await supabase.rpc("mark_dispatched", { p_outbox_id: item.id, p_error: null });
      sent += 1;
    } catch (failure) {
      await supabase.rpc("mark_dispatched", { p_outbox_id: item.id, p_error: String(failure).slice(0, 500) });
    }
  }
  return json({ sent });
});
