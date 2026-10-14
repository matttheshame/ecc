import BruskCore
import Foundation
import Observation
import SwiftUI

/// The in-app language picker's options (Settings → Language).
enum AppLanguage: String, CaseIterable, Identifiable, Sendable {
    case system
    case fr
    case nl
    case en

    var id: String { rawValue }
    var code: LanguageCode? { LanguageCode(rawValue: rawValue) }

    /// Language names are endonyms ("Nederlands" in every language), the iOS convention.
    var titleKey: LocalizedStringKey {
        switch self {
        case .system: "settings.language.system"
        case .fr: "settings.language.fr"
        case .nl: "settings.language.nl"
        case .en: "settings.language.en"
        }
    }
}

/// Owns the active language. Injected at the root as `\.locale`, so every `Text`,
/// `Label` and accessibility label re-resolves instantly when the user switches.
@MainActor
@Observable
final class LanguageStore {
    private static let defaultsKey = "brusk.language"

    private(set) var selection: AppLanguage
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        selection = defaults.string(forKey: Self.defaultsKey).flatMap(AppLanguage.init(rawValue:)) ?? .system
    }

    /// The language actually in use (device language when "system" is selected).
    var resolved: LanguageCode {
        selection.code ?? LanguageCode.bestMatch(for: Locale.preferredLanguages)
    }

    /// Belgian regional locale: drives string lookup and date/number formatting.
    var locale: Locale { Locale(identifier: resolved.formattingLocaleIdentifier) }

    func select(_ language: AppLanguage) {
        selection = language
        defaults.set(language.rawValue, forKey: Self.defaultsKey)
        // System-rendered UI (permission prompts, share sheet) follows on next launch.
        if let code = language.code {
            defaults.set([code.rawValue], forKey: "AppleLanguages")
        } else {
            defaults.removeObject(forKey: "AppleLanguages")
        }
    }
}

/// Strings needed outside the view tree (notifications, share text). Views use
/// `Text("key")` directly and pick up the environment locale.
enum L10n {
    static func string(_ key: String, language: LanguageCode) -> String {
        bundle(for: language).localizedString(forKey: key, value: nil, table: "Localizable")
    }

    /// Format strings with arguments (plural-aware through the catalog's variations).
    static func format(_ key: String, language: LanguageCode, _ arguments: CVarArg...) -> String {
        let format = bundle(for: language).localizedString(forKey: key, value: nil, table: "Localizable")
        return String(format: format, locale: Locale(identifier: language.formattingLocaleIdentifier), arguments: arguments)
    }

    private static func bundle(for language: LanguageCode) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else { return .main }
        return bundle
    }
}
