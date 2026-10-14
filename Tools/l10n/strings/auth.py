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
