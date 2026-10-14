import Foundation

/// Why a free-text note was refused. Spec §4.3: no names, no physical descriptions;
/// spec §8: free text is filtered to limit defamation and moderation load.
public enum TextIssue: String, CaseIterable, Sendable, Hashable {
    case tooLong
    case contactDetails
    case licensePlate
    case physicalDescription
    case personName

    public var messageKey: String {
        switch self {
        case .tooLong: "textguard.tooLong"
        case .contactDetails: "textguard.contactDetails"
        case .licensePlate: "textguard.licensePlate"
        case .physicalDescription: "textguard.physicalDescription"
        case .personName: "textguard.personName"
        }
    }
}

/// On-device text policy, shared by every screen that accepts free text. The server
/// applies a stricter subset again (`text_violates_policy()`), so the client check is a
/// courtesy that explains problems before sending, never the only gate.
///
/// The word lists are deliberately conservative to avoid blocking legitimate
/// descriptions of places ("sacs noirs", "zwarte zakken"): colour and size words only
/// count when they sit next to a word for a person. The app target adds NLTagger
/// person-name detection on top of this.
public enum TextGuard {
    public static let maxLength = 140

    public static func issues(in text: String) -> Set<TextIssue> {
        var found = Set<TextIssue>()
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return found }

        if trimmed.count > maxLength { found.insert(.tooLong) }

        let folded = fold(trimmed)
        if matches(Patterns.contact, in: folded) { found.insert(.contactDetails) }
        if matches(Patterns.plate, in: folded) { found.insert(.licensePlate) }
        if matches(Patterns.namingPhrase, in: trimmed, caseInsensitive: false) { found.insert(.personName) }

        let tokens = tokenize(folded)
        if tokens.contains(where: Lexicon.alwaysDescriptive.contains) || matches(Patterns.height, in: folded) {
            found.insert(.physicalDescription)
        } else if describesPersonNearby(tokens) {
            found.insert(.physicalDescription)
        }
        return found
    }

    public static func isAcceptable(_ text: String) -> Bool { issues(in: text).isEmpty }

    // MARK: - Internals

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
    }

    static func tokenize(_ s: String) -> [String] {
        s.split(whereSeparator: { !$0.isLetter && $0 != "-" }).map(String.init)
    }

    /// A colour/size/clothing word within three words of a person noun.
    static func describesPersonNearby(_ tokens: [String]) -> Bool {
        let personIndices = tokens.indices.filter { Lexicon.personNouns.contains(tokens[$0]) }
        guard !personIndices.isEmpty else { return false }
        for i in tokens.indices where Lexicon.descriptiveNearPerson.contains(tokens[i]) {
            if personIndices.contains(where: { abs($0 - i) <= 3 }) { return true }
        }
        return false
    }

    static func matches(_ pattern: String, in text: String, caseInsensitive: Bool = true) -> Bool {
        let options: NSRegularExpression.Options = caseInsensitive ? [.caseInsensitive] : []
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else { return false }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.firstMatch(in: text, options: [], range: range) != nil
    }

    enum Patterns {
        /// e-mail, URL, @handle, Belgian and international phone numbers.
        static let contact = #"([a-z0-9._%+-]+@[a-z0-9.-]+\.[a-z]{2,})|(https?://|www\.)|(^|\s)@[a-z0-9_]{2,}|((\+|00)\d{2,3}[\s.]?\d([\s./-]?\d){6,})|(\b0[1-9]([\s./-]?\d){7,8}\b)"#
        /// Belgian plates: 1-ABC-123 (current), ABC-123 and 123-ABC (older formats).
        static let plate = #"\b[1-9][ -]?[a-z]{3}[ -]?\d{3}\b|\b[a-z]{3}-?\d{3}\b|\b\d{3}-[a-z]{3}\b"#
        /// Height such as 1m80, 1 m 75, 1,90 m. Prices like "1,50 €" do not match.
        static let height = #"\b1\s?m\s?\d{2}\b|\b1[,.]\d{2}\s?m\b"#
        /// "il s'appelle Marc", "hij heet Jan", "named John", "Monsieur Dupont".
        /// Evaluated case-sensitively so the name must start with a capital letter.
        static let namingPhrase = #"(?i:s['’]appelle|nomm[ée]e?|heet|genaamd|named|called)\s+\p{Lu}\p{L}+|\b(?i:monsieur|madame|mme|meneer|mevrouw|mr\.?|mrs\.?|ms\.?)\s+\p{Lu}\p{L}+"#
    }

    enum Lexicon {
        /// Words that describe a person on their own (ethnicity, skin, hair, body marks,
        /// identifying garments). Folded: lowercase, no diacritics.
        static let alwaysDescriptive: Set<String> = [
            // FR
            "peau", "basane", "basanee", "typee", "arabe", "arabes", "africain", "africaine",
            "maghrebin", "maghrebine", "rebeu", "noiraud", "asiatique", "metis", "metisse", "rom", "roms",
            "barbu", "barbue", "barbe", "moustache", "chauve", "cheveux", "blond", "blonde", "roux", "rousse",
            "tatouage", "tatoue", "tatouee", "cicatrice", "capuche", "survetement", "voilee", "ethnie",
            // NL
            "huidskleur", "allochtoon", "allochtonen", "marokkaan", "marokkaans", "turk", "turks", "afrikaan",
            "afrikaans", "aziatisch", "baard", "snor", "kaal", "haren", "blonde", "roodharig", "bruinharig",
            "tatoeage", "litteken", "trainingspak", "hoodie", "hoofddoek", "gesluierd", "afkomst",
            // EN
            "skin", "skinned", "ethnicity", "arab", "african", "asian", "moroccan", "turkish", "roma", "gypsy",
            "beard", "bearded", "moustache", "mustache", "bald", "hair", "haired", "ginger", "tattoo", "tattooed",
            "scar", "tracksuit", "headscarf", "hijab", "veiled",
        ]

        /// Words for a person. Folded.
        static let personNouns: Set<String> = [
            // FR
            "homme", "hommes", "femme", "femmes", "mec", "mecs", "gars", "individu", "individus", "garcon",
            "garcons", "fille", "filles", "jeune", "jeunes", "personne", "personnes", "suspect", "suspects", "agresseur",
            "voleur", "voleurs", "monsieur", "dame",
            // NL
            "man", "mannen", "vrouw", "vrouwen", "jongen", "jongens", "meisje", "meisjes", "kerel", "gast", "gasten",
            "persoon", "personen", "verdachte", "dader", "daders", "dief", "dieven",
            // EN
            "men", "woman", "women", "guy", "guys", "boy", "boys", "girl", "girls", "person", "people", "thief",
            "attacker", "suspect", "bloke",
        ]

        /// Words that only describe a person when next to a person noun.
        static let descriptiveNearPerson: Set<String> = [
            // FR
            "noir", "noire", "noirs", "noires", "blanc", "blanche", "blancs", "blanches", "brun", "brune", "bruns",
            "grand", "grande", "petit", "petite", "gros", "grosse", "mince", "maigre", "vieux", "vieille", "age", "agee",
            "veste", "pantalon", "casquette", "lunettes",
            // NL
            "zwart", "zwarte", "blank", "bruin", "bruine", "groot", "grote", "klein", "kleine", "dik", "dikke",
            "dun", "dunne", "mager", "oud", "oude", "jas", "broek", "pet", "bril",
            // EN
            "black", "white", "brown", "dark", "tall", "short", "fat", "thin", "skinny", "old", "young",
            "jacket", "trousers", "cap", "glasses",
        ]
    }
}
