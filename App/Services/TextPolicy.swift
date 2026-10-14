import BruskCore
import NaturalLanguage

/// `TextGuard` (word lists and patterns, shared with tests) plus on-device person-name
/// detection with NaturalLanguage, which catches names that no list can.
enum TextPolicy {
    static func issues(in text: String) -> Set<TextIssue> {
        var issues = TextGuard.issues(in: text)
        if containsPersonalName(text) { issues.insert(.personName) }
        return issues
    }

    static func containsPersonalName(_ text: String) -> Bool {
        let tagger = NLTagger(tagSchemes: [.nameType])
        tagger.string = text
        var found = false
        tagger.enumerateTags(
            in: text.startIndex..<text.endIndex,
            unit: .word,
            scheme: .nameType,
            options: [.omitPunctuation, .omitWhitespace, .joinNames]
        ) { tag, _ in
            if tag == .personalName { found = true }
            return !found
        }
        return found
    }
}
