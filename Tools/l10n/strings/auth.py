# Onboarding, sign-in by e-mailed code (spec §4.1), settings.

STRINGS = [
    dict(key="auth.code.label", en="Verification code", fr="Code de vérification", nl="Verificatiecode"),
]

STRINGS += [
    # Language picker. Language names are endonyms, identical in every UI language.
    dict(key="settings.language.title", en="Language", fr="Langue", nl="Taal"),
    dict(key="settings.language.system", en="Same as device", fr="Comme l'appareil", nl="Zoals het toestel"),
    dict(key="settings.language.fr", en="Français", fr="Français", nl="Français", comment="Endonym: never translate."),
    dict(key="settings.language.nl", en="Nederlands", fr="Nederlands", nl="Nederlands", comment="Endonym: never translate."),
    dict(key="settings.language.en", en="English", fr="English", nl="English", comment="Endonym: never translate."),

    # Design system gallery (Debug builds).
    dict(key="settings.gallery.title", en="Design system", fr="Design system", nl="Designsysteem"),
    dict(key="settings.gallery.typography", en="Typography", fr="Typographie", nl="Typografie"),
    dict(key="settings.gallery.colors", en="Colours", fr="Couleurs", nl="Kleuren"),
    dict(key="settings.gallery.components", en="Components", fr="Composants", nl="Componenten"),
]


def plural(one, other):
    return {"one": one, "other": other}


STRINGS += [
    dict(key="map.tab", en="Map", fr="Carte", nl="Kaart"),
    dict(key="settings.title", en="Settings", fr="Réglages", nl="Instellingen"),

    # Onboarding — privacy first -------------------------------------------------------------------
    dict(key="onboarding.map.title", en="The living map of Brussels", fr="La carte vivante de Bruxelles",
         nl="De levende kaart van Brussel"),
    dict(key="onboarding.map.body",
         en="Dangerous crossings, rubbish, insecurity: report what you see in 20 seconds and follow what the city does about it.",
         fr="Carrefours dangereux, saleté, insécurité : signalez ce que vous voyez en 20 secondes et suivez ce que la ville en fait.",
         nl="Gevaarlijke kruispunten, afval, onveiligheid: meld wat je ziet in 20 seconden en volg wat de stad ermee doet."),
    dict(key="onboarding.privacy.title", en="Places, never people", fr="Des lieux, jamais des personnes", nl="Plekken, nooit personen"),
    dict(key="onboarding.privacy.body",
         en="No names, no descriptions, no suspect photos. Faces and plates are blurred on your phone. Your identity is never shown, not even as a nickname.",
         fr="Ni noms, ni descriptions, ni photos de suspects. Les visages et les plaques sont floutés sur votre téléphone. Votre identité n'est jamais affichée, pas même un pseudo.",
         nl="Geen namen, geen beschrijvingen, geen foto's van verdachten. Gezichten en nummerplaten worden op je telefoon vervaagd. Je identiteit wordt nooit getoond, zelfs geen bijnaam."),
    dict(key="onboarding.privacy.footnote", en="We only keep what the service needs.", fr="Nous ne gardons que le strict nécessaire.",
         nl="We bewaren enkel wat strikt nodig is."),
    dict(key="onboarding.neighbours.title", en="Confirmed by neighbours", fr="Confirmé par les voisin·es", nl="Bevestigd door buren"),
    dict(key="onboarding.neighbours.body",
         en="A zone appears on the map only when several people report the same thing in the same place. That keeps the map fair and fake reports out.",
         fr="Une zone n'apparaît sur la carte que lorsque plusieurs personnes signalent la même chose au même endroit. La carte reste juste et les faux signalements restent dehors.",
         nl="Een zone verschijnt pas op de kaart als meerdere mensen hetzelfde melden op dezelfde plek. Zo blijft de kaart eerlijk en blijven valse meldingen buiten."),
    dict(key="onboarding.neighbours.footnote", en="In danger? Call 112. Brusk is not an emergency service.",
         fr="En danger ? Appelez le 112. Brusk n'est pas un service d'urgence.",
         nl="In gevaar? Bel 112. Brusk is geen hulpdienst."),
    dict(key="onboarding.start", en="Open the map", fr="Ouvrir la carte", nl="Open de kaart"),

    # Sign-in (e-mail code only) --------------------------------------------------------------------
    dict(key="auth.signIn.button", en="Sign in", fr="Se connecter", nl="Aanmelden"),
    dict(key="auth.email.title", en="Sign in with your e-mail", fr="Connexion par e-mail", nl="Aanmelden met je e-mail"),
    dict(key="auth.email.message", en="We'll send you a 6-digit code. No password needed.",
         fr="Nous vous envoyons un code à 6 chiffres. Aucun mot de passe.", nl="We sturen je een code van 6 cijfers. Geen wachtwoord nodig."),
    dict(key="auth.email.label", en="E-mail address", fr="Adresse e-mail", nl="E-mailadres"),
    dict(key="auth.sendCode", en="Send the code", fr="Envoyer le code", nl="Code versturen"),
    dict(key="auth.code.title", en="Enter the code", fr="Entrez le code", nl="Voer de code in"),
    dict(key="auth.code.sentTo %@", en="Sent to %@. Check your spam folder if it doesn't arrive.",
         fr="Envoyé à %@. Vérifiez vos spams s'il n'arrive pas.", nl="Verstuurd naar %@. Kijk in je spammap als hij niet aankomt."),
    dict(key="auth.code.verifying", en="Checking…", fr="Vérification…", nl="Controleren…"),
    dict(key="auth.code.resend", en="Send a new code", fr="Renvoyer un code", nl="Nieuwe code sturen"),
    dict(key="auth.code.resendIn %lld", en=plural("New code in %lld s", "New code in %lld s"),
         fr=plural("Nouveau code dans %lld s", "Nouveau code dans %lld s"), nl=plural("Nieuwe code over %lld s", "Nieuwe code over %lld s")),
    dict(key="auth.code.changeEmail", en="Change e-mail", fr="Changer d'e-mail", nl="E-mailadres wijzigen"),
    dict(key="auth.privacy", en="Your e-mail is only used to sign you in. It is never shown to anyone.",
         fr="Votre e-mail sert uniquement à vous connecter. Il n'est jamais montré à personne.",
         nl="Je e-mailadres dient enkel om je aan te melden. Het wordt nooit aan iemand getoond."),

    # Settings ---------------------------------------------------------------------------------------
    dict(key="settings.language.footer", en="Changes apply instantly.", fr="Le changement est immédiat.", nl="Wijzigingen gelden meteen."),
    dict(key="settings.account.title", en="Account", fr="Compte", nl="Account"),
    dict(key="settings.account.email", en="E-mail", fr="E-mail", nl="E-mail"),
    dict(key="settings.account.footer", en="Only you can see your e-mail and your trust level.",
         fr="Vous seul·e voyez votre e-mail et votre niveau de confiance.", nl="Enkel jij ziet je e-mailadres en je vertrouwensniveau."),
    dict(key="settings.signOut", en="Sign out", fr="Se déconnecter", nl="Afmelden"),
    dict(key="settings.delete.button", en="Delete my account and data", fr="Supprimer mon compte et mes données",
         nl="Mijn account en gegevens verwijderen"),
    dict(key="settings.delete.title", en="Delete your account?", fr="Supprimer votre compte ?", nl="Je account verwijderen?"),
    dict(key="settings.delete.message",
         en="Your account, notes, photos and walk data are erased. Zone counts keep an anonymous trace of your past reports.",
         fr="Votre compte, vos notes, photos et trajets sont effacés. Les comptages des zones gardent une trace anonyme de vos anciens signalements.",
         nl="Je account, notities, foto's en wandelgegevens worden gewist. De zonetellingen behouden een anoniem spoor van je eerdere meldingen."),
    dict(key="settings.delete.confirm", en="Delete everything", fr="Tout supprimer", nl="Alles verwijderen"),
    dict(key="settings.privacy.title", en="Privacy", fr="Vie privée", nl="Privacy"),
    dict(key="settings.privacy.what", en="What we store and why", fr="Ce que nous conservons et pourquoi", nl="Wat we bewaren en waarom"),
    dict(key="settings.privacy.policy", en="Privacy policy", fr="Politique de confidentialité", nl="Privacybeleid"),
    dict(key="settings.privacy.terms", en="Terms of use", fr="Conditions d'utilisation", nl="Gebruiksvoorwaarden"),
    dict(key="settings.about.title", en="About", fr="À propos", nl="Over"),
    dict(key="settings.about.version", en="Version", fr="Version", nl="Versie"),
    dict(key="settings.about.demo", en="Demo mode: no server configured", fr="Mode démo : aucun serveur configuré",
         nl="Demomodus: geen server ingesteld"),

    # Privacy explainer (draft — align with the lawyer-reviewed policy) -----------------------------
    dict(key="privacy.collect.title", en="What we collect", fr="Ce que nous collectons", nl="Wat we verzamelen"),
    dict(key="privacy.collect.body",
         en="Your e-mail, to sign in. For each report: a category, a place, a time, and optionally a short note and a blurred photo. For a walk home: your contact's e-mail and your latest position.",
         fr="Votre e-mail, pour la connexion. Pour chaque signalement : une catégorie, un lieu, une heure et, si vous le souhaitez, une courte note et une photo floutée. Pour un trajet : l'e-mail de votre contact et votre dernière position.",
         nl="Je e-mailadres, om aan te melden. Per melding: een categorie, een plek, een tijdstip en eventueel een korte notitie en een vervaagde foto. Voor een wandeling naar huis: het e-mailadres van je contactpersoon en je laatste positie."),
    dict(key="privacy.never.title", en="What we never collect", fr="Ce que nous ne collectons jamais", nl="Wat we nooit verzamelen"),
    dict(key="privacy.never.body",
         en="Names, descriptions or photos of people, your contacts, your location in the background outside a walk, advertising or tracking identifiers.",
         fr="Des noms, descriptions ou photos de personnes, vos contacts, votre position en arrière-plan hors d'un trajet, des identifiants publicitaires ou de pistage.",
         nl="Namen, beschrijvingen of foto's van personen, je contacten, je locatie op de achtergrond buiten een wandeling, reclame- of trackingidentificatoren."),
    dict(key="privacy.who.title", en="Who sees what", fr="Qui voit quoi", nl="Wie ziet wat"),
    dict(key="privacy.who.body",
         en="Everyone sees aggregated zones only. You alone see your reports and their exact place. Confirmed road and cleanliness reports go to the responsible service. Theft, aggression and harassment are never passed to the police without your consent.",
         fr="Tout le monde ne voit que des zones agrégées. Vous seul·e voyez vos signalements et leur emplacement exact. Les signalements confirmés de voirie et de propreté sont transmis au service compétent. Vols, agressions et harcèlement ne sont jamais transmis à la police sans votre accord.",
         nl="Iedereen ziet enkel samengevoegde zones. Alleen jij ziet je meldingen en hun exacte plek. Bevestigde meldingen over wegen en netheid gaan naar de bevoegde dienst. Diefstal, agressie en intimidatie gaan nooit zonder je toestemming naar de politie."),
    dict(key="privacy.retention.title", en="How long", fr="Combien de temps", nl="Hoe lang"),
    dict(key="privacy.retention.body",
         en="Reports are made anonymous after 12 months. Walk data is erased 24 hours after the walk. Deleting your account erases your data immediately.",
         fr="Les signalements sont anonymisés après 12 mois. Les données de trajet sont effacées 24 heures après le trajet. Supprimer votre compte efface vos données immédiatement.",
         nl="Meldingen worden na 12 maanden geanonimiseerd. Wandelgegevens worden 24 uur na de wandeling gewist. Je account verwijderen wist je gegevens meteen."),
    dict(key="privacy.rights.title", en="Your rights", fr="Vos droits", nl="Je rechten"),
    dict(key="privacy.rights.body",
         en="Under the GDPR you can access, correct and erase your data. Delete your account here at any time; data is hosted in the EU.",
         fr="Le RGPD vous permet d'accéder à vos données, de les corriger et de les effacer. Supprimez votre compte ici à tout moment ; les données sont hébergées dans l'UE.",
         nl="Volgens de AVG kan je je gegevens inzien, verbeteren en wissen. Verwijder je account hier op elk moment; de gegevens worden in de EU gehost."),
]
