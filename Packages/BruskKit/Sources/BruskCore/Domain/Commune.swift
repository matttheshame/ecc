import Foundation

/// The 19 communes of the Brussels-Capital Region, with their official French and Dutch
/// names and NIS codes. Commune names are proper nouns: they are not translated through
/// the string catalog. English uses the French name, as is customary in Brussels.
public struct Commune: Hashable, Sendable, Identifiable {
    public let nisCode: String
    public let nameFR: String
    public let nameNL: String

    public var id: String { nisCode }

    public func name(in language: LanguageCode) -> String {
        switch language {
        case .nl: nameNL
        case .fr, .en: nameFR
        }
    }

    public static let all: [Commune] = [
        Commune(nisCode: "21001", nameFR: "Anderlecht", nameNL: "Anderlecht"),
        Commune(nisCode: "21002", nameFR: "Auderghem", nameNL: "Oudergem"),
        Commune(nisCode: "21003", nameFR: "Berchem-Sainte-Agathe", nameNL: "Sint-Agatha-Berchem"),
        Commune(nisCode: "21004", nameFR: "Bruxelles", nameNL: "Brussel"),
        Commune(nisCode: "21005", nameFR: "Etterbeek", nameNL: "Etterbeek"),
        Commune(nisCode: "21006", nameFR: "Evere", nameNL: "Evere"),
        Commune(nisCode: "21007", nameFR: "Forest", nameNL: "Vorst"),
        Commune(nisCode: "21008", nameFR: "Ganshoren", nameNL: "Ganshoren"),
        Commune(nisCode: "21009", nameFR: "Ixelles", nameNL: "Elsene"),
        Commune(nisCode: "21010", nameFR: "Jette", nameNL: "Jette"),
        Commune(nisCode: "21011", nameFR: "Koekelberg", nameNL: "Koekelberg"),
        Commune(nisCode: "21012", nameFR: "Molenbeek-Saint-Jean", nameNL: "Sint-Jans-Molenbeek"),
        Commune(nisCode: "21013", nameFR: "Saint-Gilles", nameNL: "Sint-Gillis"),
        Commune(nisCode: "21014", nameFR: "Saint-Josse-ten-Noode", nameNL: "Sint-Joost-ten-Node"),
        Commune(nisCode: "21015", nameFR: "Schaerbeek", nameNL: "Schaarbeek"),
        Commune(nisCode: "21016", nameFR: "Uccle", nameNL: "Ukkel"),
        Commune(nisCode: "21017", nameFR: "Watermael-Boitsfort", nameNL: "Watermaal-Bosvoorde"),
        Commune(nisCode: "21018", nameFR: "Woluwe-Saint-Lambert", nameNL: "Sint-Lambrechts-Woluwe"),
        Commune(nisCode: "21019", nameFR: "Woluwe-Saint-Pierre", nameNL: "Sint-Pieters-Woluwe"),
    ]

    public static func with(code: String?) -> Commune? {
        guard let code else { return nil }
        return all.first { $0.nisCode == code }
    }

    /// Communes sorted alphabetically in the given language.
    public static func sorted(in language: LanguageCode) -> [Commune] {
        let locale = Locale(identifier: language.formattingLocaleIdentifier)
        return all.sorted {
            $0.name(in: language).compare($1.name(in: language), options: [.caseInsensitive, .diacriticInsensitive], locale: locale) == .orderedAscending
        }
    }
}
