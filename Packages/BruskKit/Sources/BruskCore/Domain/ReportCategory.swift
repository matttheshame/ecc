import Foundation

/// What can be reported (spec §5, écran 2). A report describes a place, never a person.
public enum ReportCategory: String, CaseIterable, Codable, Sendable, Identifiable {
    case road
    case cleanliness
    case insecurity
    case harassment

    public var id: String { rawValue }

    /// Theft/aggression and harassment trigger the "help first" banner (spec §4.4).
    public var isSerious: Bool {
        switch self {
        case .road, .cleanliness: false
        case .insecurity, .harassment: true
        }
    }

    /// Serious categories are never transmitted to a service automatically (spec §6).
    public var allowsAutomaticRouting: Bool { !isSerious }

    public var symbolName: String {
        switch self {
        case .road: "exclamationmark.triangle"
        case .cleanliness: "trash"
        case .insecurity: "hand.raised"
        case .harassment: "figure.stand.line.dotted.figure.stand"
        }
    }

    public var paletteToken: PaletteToken {
        switch self {
        case .road: .categoryRoad
        case .cleanliness: .categoryCleanliness
        case .insecurity: .categoryInsecurity
        case .harassment: .categoryHarassment
        }
    }

    /// Full name, used in titles and VoiceOver.
    public var titleKey: String {
        switch self {
        case .road: "category.road.title"
        case .cleanliness: "category.cleanliness.title"
        case .insecurity: "category.insecurity.title"
        case .harassment: "category.harassment.title"
        }
    }

    /// Short name for chips and the map legend.
    public var shortTitleKey: String {
        switch self {
        case .road: "category.road.short"
        case .cleanliness: "category.cleanliness.short"
        case .insecurity: "category.insecurity.short"
        case .harassment: "category.harassment.short"
        }
    }

    /// One-line explanation under the big tile in the report flow.
    public var hintKey: String {
        switch self {
        case .road: "category.road.hint"
        case .cleanliness: "category.cleanliness.hint"
        case .insecurity: "category.insecurity.hint"
        case .harassment: "category.harassment.hint"
        }
    }
}
