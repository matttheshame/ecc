# Info.plist strings: app name and permission prompts. Apple reviews these: each says
# exactly what the permission is for and that it is optional where it is.

INFOPLIST = [
    dict(key="CFBundleDisplayName", en="Brusk", fr="Brusk", nl="Brusk"),
    dict(key="NSLocationWhenInUseUsageDescription",
         en="Your location places the pin when you report, and shows reports near you to confirm. It is never shown to anyone.",
         fr="Votre position place l'épingle quand vous signalez et affiche les signalements proches à confirmer. Elle n'est jamais montrée à personne.",
         nl="Je locatie plaatst de speld wanneer je meldt en toont meldingen in de buurt om te bevestigen. Ze wordt nooit aan iemand getoond."),
    dict(key="NSCameraUsageDescription",
         en="Optional: take a photo of the place. Faces and licence plates are blurred on your phone before anything is sent.",
         fr="Facultatif : photographiez le lieu. Les visages et les plaques sont floutés sur votre téléphone avant tout envoi.",
         nl="Optioneel: maak een foto van de plek. Gezichten en nummerplaten worden op je telefoon vervaagd vóór er iets verstuurd wordt."),
]
