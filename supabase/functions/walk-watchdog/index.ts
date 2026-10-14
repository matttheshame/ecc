// Every minute (pg_cron): alert the contact of each walk whose arrival was not
// confirmed in time. claim_overdue_walks() marks rows atomically, so a contact is
// e-mailed at most once even if two runs overlap.
import { adminClient, isServiceCall, json, sendEmail } from "../_shared/server.ts";
import { escapeHTML, formatTime, type Lang, t } from "../_shared/i18n.ts";

interface OverdueWalk {
  id: string;
  contact_email: string;
  language: Lang;
  share_token: string;
  expected_arrival_at: string;
  last_lat: number | null;
  last_lon: number | null;
  last_seen_at: string | null;
}

Deno.serve(async (request) => {
  if (!isServiceCall(request)) return json({ error: "forbidden" }, 403);
  const supabase = adminClient();
  const { data, error } = await supabase.rpc("claim_overdue_walks");
  if (error) return json({ error: error.message }, 500);

  const walks = (data ?? []) as OverdueWalk[];
  const baseURL = `${Deno.env.get("SUPABASE_URL")}/functions/v1/walk-view?t=`;
  const failures: string[] = [];

  for (const walk of walks) {
    const lang = walk.language;
    const link = baseURL + walk.share_token;
    const lastSeen = formatTime(walk.last_seen_at, lang);
    const lines = [
      t("alertBody", lang),
      "",
      `${t("expectedAt", lang)} ${formatTime(walk.expected_arrival_at, lang)}`,
      lastSeen ? `${t("lastPosition", lang)} (${t("seenAt", lang)} ${lastSeen}): ${link}` : link,
      "",
      t("emergency", lang),
      "",
      t("alertFooter", lang),
    ];
    try {
      await sendEmail({
        to: walk.contact_email,
        subject: t("alertSubject", lang),
        text: lines.join("\n"),
        html: `<p>${escapeHTML(t("alertBody", lang))}</p>
               <p><a href="${escapeHTML(link)}">${escapeHTML(t("openMap", lang))}</a></p>
               <p><strong>${escapeHTML(t("emergency", lang))}</strong></p>
               <p style="color:#55525F;font-size:13px">${escapeHTML(t("alertFooter", lang))}</p>`,
      });
    } catch (failure) {
      // The walk stays "alerted" (visible on the page). Log for the on-call person.
      console.error(`[walk-watchdog] e-mail failed for walk ${walk.id}: ${failure}`);
      failures.push(walk.id);
    }
  }
  return json({ alerted: walks.length, failed: failures.length }, failures.length ? 502 : 200);
});
