import Foundation

/// Lifecycle of a report (spec §5, écran 3). Ordered: a report only moves forward.
public enum ReportStatus: String, CaseIterable, Codable, Sendable, Comparable {
    case pending
    case confirmed
    case sent
    case resolved

    /// 1-based position, shown as "step 2 of 4" to VoiceOver.
    public var step: Int {
        switch self {
        case .pending: 1
        case .confirmed: 2
        case .sent: 3
        case .resolved: 4
        }
    }

    public static func < (lhs: ReportStatus, rhs: ReportStatus) -> Bool { lhs.step < rhs.step }

    public var isOpen: Bool { self != .resolved }

    public var symbolName: String {
        switch self {
        case .pending: "clock"
        case .confirmed: "person.2"
        case .sent: "paperplane"
        case .resolved: "checkmark.circle"
        }
    }

    public var paletteToken: PaletteToken {
        switch self {
        case .pending: .statusPending
        case .confirmed: .statusConfirmed
        case .sent: .statusSent
        case .resolved: .statusResolved
        }
    }

    public var titleKey: String {
        switch self {
        case .pending: "status.pending.title"
        case .confirmed: "status.confirmed.title"
        case .sent: "status.sent.title"
        case .resolved: "status.resolved.title"
        }
    }

    /// What this status means for the person who reported, in one sentence.
    public var explanationKey: String {
        switch self {
        case .pending: "status.pending.explanation"
        case .confirmed: "status.confirmed.explanation"
        case .sent: "status.sent.explanation"
        case .resolved: "status.resolved.explanation"
        }
    }
}

/// Where a confirmed report is routed (spec §6). Serious categories never route automatically.
public enum RoutingDestination: String, Codable, Sendable, CaseIterable {
    case bruxellesProprete = "bruxelles_proprete"
    case communeCleanliness = "commune_cleanliness"
    case commune
    case bruxellesMobilite = "bruxelles_mobilite"

    public var titleKey: String {
        switch self {
        case .bruxellesProprete: "routing.bruxellesProprete"
        case .communeCleanliness: "routing.communeCleanliness"
        case .commune: "routing.commune"
        case .bruxellesMobilite: "routing.bruxellesMobilite"
        }
    }
}
