import Testing
@testable import BruskCore

@Suite("Text policy (spec §4.3: a place, never a person)")
struct TextGuardTests {
    @Test("Place descriptions are accepted in FR, NL and EN", arguments: [
        "Sacs noirs éventrés devant l'arrêt de tram",
        "Trou dans la chaussée, dangereux pour les vélos",
        "Ce type de dépôt revient chaque semaine",
        "Zwarte vuilniszakken naast de glasbak",
        "Haar fiets werd hier bijna aangereden, gevaarlijk kruispunt",
        "Broken street light, very dark at night",
        "Ticket à 1,50 € — la borne est cassée",
        "Bus 136 s'arrête au milieu du passage piéton",
        "Le trottoir est encombré depuis 10 ans",
        "",
    ])
    func acceptsPlaces(text: String) {
        #expect(TextGuard.issues(in: text).isEmpty, "\(text) → \(TextGuard.issues(in: text))")
    }

    @Test("Physical descriptions of people are refused", arguments: [
        "Un homme noir avec une capuche",
        "Grand homme barbu, cheveux courts",
        "Een man met een baard en een tatoeage",
        "Twee jongens, de ene zwarte jas",
        "Tall guy with a beard",
        "A young man wearing a black jacket",
        "Individu d'environ 1m80",
        "Dader ongeveer 1,85 m",
    ])
    func refusesDescriptions(text: String) {
        #expect(TextGuard.issues(in: text).contains(.physicalDescription), "\(text)")
    }

    @Test("Names are refused", arguments: [
        "Il s'appelle Marc et habite au coin",
        "Hij heet Jan",
        "The owner named John",
        "C'est Monsieur Dupont du 3e",
    ])
    func refusesNames(text: String) {
        #expect(TextGuard.issues(in: text).contains(.personName), "\(text)")
    }

    @Test("Contact details are refused", arguments: [
        "Appelez le 0470 12 34 56",
        "+32 470 12 34 56",
        "écrivez à jean@example.org",
        "voir www.example.com",
        "suivez @someone",
    ])
    func refusesContact(text: String) {
        #expect(TextGuard.issues(in: text).contains(.contactDetails), "\(text)")
    }

    @Test("Licence plates are refused", arguments: ["Voiture 1-ABC-123 garée", "plaque abc-123", "1 XYZ 987 op het fietspad"])
    func refusesPlates(text: String) {
        #expect(TextGuard.issues(in: text).contains(.licensePlate), "\(text)")
    }

    @Test("Dates are not mistaken for phone numbers")
    func datesAreFine() {
        #expect(TextGuard.issues(in: "Depuis le 01/10/2026, rien n'a bougé").isEmpty)
    }

    @Test("Length limit")
    func length() {
        #expect(TextGuard.issues(in: String(repeating: "a", count: 140)).isEmpty)
        #expect(TextGuard.issues(in: String(repeating: "a", count: 141)) == [.tooLong])
    }
}
