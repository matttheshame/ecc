// Server-side copy (e-mails, the walk page). Same voice as the app: French "vous",
// Dutch "je". Needs the same native-speaker review as Localizable.xcstrings.

export type Lang = "fr" | "nl" | "en";

export function pickLanguage(acceptLanguage: string | null, fallback: Lang): Lang {
  for (const part of (acceptLanguage ?? "").split(",")) {
    const code = part.trim().slice(0, 2).toLowerCase();
    if (code === "fr" || code === "nl" || code === "en") return code;
  }
  return fallback;
}

const strings = {
  walkPageTitle: { fr: "Trajet en direct", nl: "Wandeling live", en: "Live walk" },
  walkActive: {
    fr: "Votre proche rentre à pied et partage sa position avec vous.",
    nl: "Je naaste wandelt naar huis en deelt de locatie met jou.",
    en: "Someone close to you is walking home and sharing their location with you.",
  },
  walkAlerted: {
    fr: "L'arrivée n'a pas été confirmée à temps. Essayez de joindre la personne. En cas de danger, appelez le 112.",
    nl: "De aankomst werd niet op tijd bevestigd. Probeer de persoon te bereiken. Bij gevaar: bel 112.",
    en: "Arrival was not confirmed in time. Try to reach them. If you think they are in danger, call 112.",
  },
  walkArrived: { fr: "Bien arrivé·e. Le partage est terminé.", nl: "Goed aangekomen. Het delen is gestopt.", en: "Arrived safely. Sharing has ended." },
  walkCancelled: { fr: "Le partage a été arrêté.", nl: "Het delen werd gestopt.", en: "Sharing was stopped." },
  walkUnknown: { fr: "Ce lien n'est plus valide.", nl: "Deze link is niet meer geldig.", en: "This link is no longer valid." },
  lastPosition: { fr: "Dernière position", nl: "Laatste positie", en: "Last position" },
  seenAt: { fr: "Mise à jour à", nl: "Bijgewerkt om", en: "Updated at" },
  expectedAt: { fr: "Arrivée prévue à", nl: "Verwacht om", en: "Expected at" },
  openMap: { fr: "Ouvrir la carte", nl: "Kaart openen", en: "Open the map" },
  noPosition: { fr: "Position pas encore reçue.", nl: "Nog geen positie ontvangen.", en: "No position received yet." },
  autoRefresh: { fr: "Cette page se met à jour toutes les 30 secondes.", nl: "Deze pagina vernieuwt elke 30 seconden.", en: "This page refreshes every 30 seconds." },
  emergency: { fr: "Urgence : 112", nl: "Noodgeval: 112", en: "Emergency: 112" },

  alertSubject: {
    fr: "Brusk · Arrivée non confirmée",
    nl: "Brusk · Aankomst niet bevestigd",
    en: "Brusk · Arrival not confirmed",
  },
  alertBody: {
    fr: "La personne qui partageait son trajet avec vous n'a pas confirmé son arrivée à l'heure prévue. Essayez de la joindre. Si vous pensez qu'elle est en danger, appelez le 112.",
    nl: "De persoon die haar wandeling met jou deelde, heeft haar aankomst niet op tijd bevestigd. Probeer haar te bereiken. Denk je dat ze in gevaar is, bel dan 112.",
    en: "The person sharing their walk with you has not confirmed they arrived on time. Try to reach them. If you think they are in danger, call 112.",
  },
  alertFooter: {
    fr: "Vous recevez ce message une seule fois, parce que cette personne vous a choisi·e comme contact pour ce trajet. Votre adresse est supprimée 24 heures après.",
    nl: "Je krijgt dit bericht één keer, omdat deze persoon jou als contact koos voor deze wandeling. Je adres wordt na 24 uur gewist.",
    en: "You receive this message once, because this person chose you as their contact for this walk. Your address is deleted 24 hours later.",
  },
} as const;

export type Key = keyof typeof strings;

export function t(key: Key, lang: Lang): string {
  return strings[key][lang];
}

export const categoryNames: Record<string, { fr: string; nl: string }> = {
  road: { fr: "Route dangereuse", nl: "Gevaarlijke weg" },
  cleanliness: { fr: "Saleté / poubelles", nl: "Afval en vuil" },
  insecurity: { fr: "Vol / agression", nl: "Diefstal / agressie" },
  harassment: { fr: "Harcèlement", nl: "Intimidatie" },
};

export function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

export function formatTime(iso: string | null, lang: Lang): string | null {
  if (!iso) return null;
  const locale = { fr: "fr-BE", nl: "nl-BE", en: "en-BE" }[lang];
  return new Intl.DateTimeFormat(locale, { hour: "2-digit", minute: "2-digit", timeZone: "Europe/Brussels" }).format(new Date(iso));
}
