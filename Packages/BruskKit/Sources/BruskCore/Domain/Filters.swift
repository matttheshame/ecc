import Foundation

/// Map time window (spec §5, écran 1: 7 days, 30 days, 12 months).
public enum Period: Int, CaseIterable, Codable, Sendable, Identifiable {
    case week = 7
    case month = 30
    case year = 365

    public var id: Int { rawValue }
    public var days: Int { rawValue }

    public var titleKey: String {
        switch self {
        case .week: "period.week"
        case .month: "period.month"
        case .year: "period.year"
        }
    }
}

/// Everything the map can be filtered on.
public struct ZoneFilter: Hashable, Codable, Sendable {
    public var categories: Set<ReportCategory>
    public var period: Period
    public var communeCode: String?

    public init(
        categories: Set<ReportCategory> = Set(ReportCategory.allCases),
        period: Period = .month,
        communeCode: String? = nil
    ) {
        self.categories = categories
        self.period = period
        self.communeCode = communeCode
    }

    public var isDefault: Bool { self == ZoneFilter() }

    /// Stable key used to cache zone payloads per filter.
    public var cacheKey: String {
        let cats = categories.map(\.rawValue).sorted().joined(separator: ",")
        return "\(cats)|\(period.rawValue)|\(communeCode ?? "all")"
    }
}

/// Language codes the product supports. Also used server-side for e-mails.
public enum LanguageCode: String, CaseIterable, Codable, Sendable {
    case fr
    case nl
    case en

    /// Region-specific locale for formatting dates and numbers the Belgian way.
    public var formattingLocaleIdentifier: String {
        switch self {
        case .fr: "fr_BE"
        case .nl: "nl_BE"
        case .en: "en_BE"
        }
    }

    /// Picks the best supported language for a list of preferred languages (e.g. `Locale.preferredLanguages`).
    public static func bestMatch(for preferred: [String]) -> LanguageCode {
        for identifier in preferred {
            let base = identifier.lowercased().split(whereSeparator: { $0 == "-" || $0 == "_" }).first.map(String.init)
            if let base, let match = LanguageCode(rawValue: base) { return match }
        }
        return .fr
    }
}
