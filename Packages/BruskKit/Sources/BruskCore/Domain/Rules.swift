import Foundation

// MARK: - Trust

/// What a user sees about their own trust (never anyone else's). Spec §4.2.
public enum TrustLevel: String, Codable, Sendable, CaseIterable {
    case new
    case established
    case trusted

    public init(weight: Double) {
        switch weight {
        case ..<0.45: self = .new
        case ..<0.75: self = .established
        default: self = .trusted
        }
    }

    public var titleKey: String {
        switch self {
        case .new: "trust.new.title"
        case .established: "trust.established.title"
        case .trusted: "trust.trusted.title"
        }
    }

    public var explanationKey: String {
        switch self {
        case .new: "trust.new.explanation"
        case .established: "trust.established.explanation"
        case .trusted: "trust.trusted.explanation"
        }
    }
}

public struct TrustInfo: Hashable, Codable, Sendable {
    public let weight: Double
    public let validatedReports: Int
    public let usefulConfirmations: Int

    public init(weight: Double, validatedReports: Int, usefulConfirmations: Int) {
        self.weight = weight
        self.validatedReports = validatedReports
        self.usefulConfirmations = usefulConfirmations
    }

    public var level: TrustLevel { TrustLevel(weight: weight) }
}

// MARK: - Report validation

public enum ReportValidationIssue: String, Sendable, Hashable, CaseIterable {
    case outsideBrussels
    case occurredInFuture
    case occurredTooLongAgo
    case noteRejected

    public var messageKey: String {
        switch self {
        case .outsideBrussels: "report.validation.outsideBrussels"
        case .occurredInFuture: "report.validation.future"
        case .occurredTooLongAgo: "report.validation.tooOld"
        case .noteRejected: "report.validation.note"
        }
    }
}

public enum ReportRules {
    /// A report must describe something that happened in the last 7 days.
    public static let maxAge: TimeInterval = 7 * 24 * 3600
    /// Clock skew tolerated for "now".
    public static let futureTolerance: TimeInterval = 5 * 60

    public static func validate(coordinate: GeoCoordinate, occurredAt: Date, note: String?, now: Date = Date()) -> Set<ReportValidationIssue> {
        var issues = Set<ReportValidationIssue>()
        if !Brussels.contains(coordinate) { issues.insert(.outsideBrussels) }
        if occurredAt > now.addingTimeInterval(futureTolerance) { issues.insert(.occurredInFuture) }
        if occurredAt < now.addingTimeInterval(-maxAge) { issues.insert(.occurredTooLongAgo) }
        if let note, !TextGuard.isAcceptable(note) { issues.insert(.noteRejected) }
        return issues
    }
}

// MARK: - Age of unresolved problems

public enum ProblemAge {
    /// Whole calendar days between `since` and `now` ("Reported 12 days ago").
    public static func days(since: Date, now: Date = Date(), calendar: Calendar = .current) -> Int {
        let start = calendar.startOfDay(for: since)
        let end = calendar.startOfDay(for: now)
        return max(0, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }
}

// MARK: - Deep links

/// `brusk://zone/road/12/-34` and `https://brusk.app/z/road/12/-34` open a zone.
public enum DeepLink: Hashable, Sendable {
    case zone(ZoneID)
    case help
    case report

    public static let scheme = "brusk"
    /// Placeholder domain. Must match the Associated Domains entitlement (human task).
    public static let universalHost = "brusk.app"

    public init?(url: URL) {
        let parts: [String]
        if url.scheme == Self.scheme {
            parts = ([url.host].compactMap { $0 } + url.pathComponents.filter { $0 != "/" })
        } else if url.scheme == "https", url.host == Self.universalHost {
            parts = url.pathComponents.filter { $0 != "/" }
        } else {
            return nil
        }
        switch parts.first {
        case "zone", "z":
            guard parts.count == 4,
                  let category = ReportCategory(rawValue: parts[1]),
                  let i = Int(parts[2]), let j = Int(parts[3]) else { return nil }
            self = .zone(ZoneID(category: category, hexI: i, hexJ: j))
        case "help": self = .help
        case "report": self = .report
        default: return nil
        }
    }

    /// Public, shareable link (used in share cards).
    public var shareURL: URL {
        switch self {
        case .zone(let id):
            URL(string: "https://\(Self.universalHost)/z/\(id.category.rawValue)/\(id.hexI)/\(id.hexJ)")!
        case .help:
            URL(string: "https://\(Self.universalHost)/help")!
        case .report:
            URL(string: "https://\(Self.universalHost)/report")!
        }
    }
}
