// Public page the walker's contact opens (spec §5 écran 4, "Je rentre seul·e").
// Deployed with verify_jwt = false: the unguessable token in the link is the access
// control. Shows the last position only while the walk is active, never a trail.
import { adminClient } from "../_shared/server.ts";
import { escapeHTML, formatTime, type Lang, pickLanguage, t } from "../_shared/i18n.ts";

interface WalkView {
  status: "active" | "arrived" | "alerted" | "cancelled";
  language: Lang;
  expected_arrival_at: string;
  last_seen_at: string | null;
  last_lat: number | null;
  last_lon: number | null;
}

Deno.serve(async (request) => {
  const token = new URL(request.url).searchParams.get("t") ?? "";
  let view: WalkView | null = null;
  if (/^[0-9a-f]{48}$/.test(token)) {
    const { data } = await adminClient().rpc("walk_public_view", { p_token: token });
    view = data as WalkView | null;
  }
  const lang = pickLanguage(request.headers.get("Accept-Language"), view?.language ?? "fr");
  return new Response(render(view, lang), {
    status: view ? 200 : 404,
    headers: {
      "Content-Type": "text/html; charset=utf-8",
      "Cache-Control": "no-store",
      "X-Robots-Tag": "noindex, nofollow",
      "Referrer-Policy": "no-referrer",
      "Content-Security-Policy": "default-src 'none'; style-src 'unsafe-inline'; img-src 'none'; base-uri 'none'; form-action 'none'",
    },
  });
});

function render(view: WalkView | null, lang: Lang): string {
  let body: string;
  if (!view) {
    body = `<p class="lead">${escapeHTML(t("walkUnknown", lang))}</p>`;
  } else {
    const message = {
      active: t("walkActive", lang),
      alerted: t("walkAlerted", lang),
      arrived: t("walkArrived", lang),
      cancelled: t("walkCancelled", lang),
    }[view.status];
    const position = view.last_lat !== null && view.last_lon !== null
      ? `<p><strong>${escapeHTML(t("lastPosition", lang))}</strong><br>
           ${escapeHTML(t("seenAt", lang))} ${escapeHTML(formatTime(view.last_seen_at, lang) ?? "—")}</p>
         <p><a class="button" href="https://www.openstreetmap.org/?mlat=${view.last_lat.toFixed(5)}&amp;mlon=${view.last_lon.toFixed(5)}#map=17/${view.last_lat.toFixed(5)}/${view.last_lon.toFixed(5)}" rel="noopener">${escapeHTML(t("openMap", lang))}</a></p>`
      : (view.status === "active" || view.status === "alerted") ? `<p>${escapeHTML(t("noPosition", lang))}</p>` : "";
    const expected = view.status === "active"
      ? `<p>${escapeHTML(t("expectedAt", lang))} ${escapeHTML(formatTime(view.expected_arrival_at, lang) ?? "—")}</p>`
      : "";
    body = `<p class="lead ${view.status === "alerted" ? "alert" : ""}">${escapeHTML(message)}</p>${expected}${position}
      <p class="small">${escapeHTML(t("autoRefresh", lang))}</p>
      <p><a class="button danger" href="tel:112">${escapeHTML(t("emergency", lang))}</a></p>`;
  }
  return `<!doctype html>
<html lang="${lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<meta http-equiv="refresh" content="30">
<meta name="robots" content="noindex, nofollow">
<title>Brusk · ${escapeHTML(t("walkPageTitle", lang))}</title>
<style>
  :root { color-scheme: light dark; --bg: #F6F4EF; --ink: #1C1B22; --muted: #55525F; --accent: #4A3F9E; --danger: #B3261E; }
  @media (prefers-color-scheme: dark) { :root { --bg: #141418; --ink: #F2F0EB; --muted: #B6B3BE; --accent: #AFA4F0; --danger: #C8372D; } }
  body { margin: 0; padding: 24px 16px; background: var(--bg); color: var(--ink); font: 17px/1.5 -apple-system, BlinkMacSystemFont, "Segoe UI", sans-serif; }
  main { max-width: 480px; margin: 0 auto; }
  h1 { font-size: 28px; margin: 0 0 16px; }
  .lead { font-size: 20px; } .alert { color: var(--danger); font-weight: 600; }
  .small { color: var(--muted); font-size: 14px; }
  .button { display: inline-block; min-height: 44px; padding: 12px 20px; border-radius: 16px; background: var(--accent); color: #fff; text-decoration: none; font-weight: 600; box-sizing: border-box; }
  .danger { background: var(--danger); }
  @media (prefers-color-scheme: dark) { .button:not(.danger) { color: #141418; } }
</style>
</head>
<body><main><h1>Brusk · ${escapeHTML(t("walkPageTitle", lang))}</h1>${body}</main></body>
</html>`;
}
