import Foundation

/// "Je rentre seul·e" (spec §5, écran 4). Pure timing rules; networking and location
/// live in the app target.
public struct WalkPlan: Hashable, Codable, Sendable {
    public static let durationChoices: [Int] = [10, 20, 30, 45, 60]
    /// Ask the walker "Are you home?" this long before the deadline.
    public static let reminderLead: TimeInterval = 5 * 60
    /// The server alerts the contact this long after the deadline without confirmation.
    public static let grace: TimeInterval = 5 * 60
    public static let extensionStep: TimeInterval = 10 * 60
    /// Hard ceiling so a forgotten session cannot share location indefinitely.
    public static let maxDuration: TimeInterval = 3 * 3600

    public let startedAt: Date
    public private(set) var expectedArrival: Date

    public init(startedAt: Date, minutes: Int) {
        self.startedAt = startedAt
        self.expectedArrival = startedAt.addingTimeInterval(TimeInterval(minutes) * 60)
    }

    public enum Phase: Equatable, Sendable {
        case onTrack(remaining: TimeInterval)
        case dueSoon(remaining: TimeInterval)
        case overdue(late: TimeInterval)
        /// The server has alerted (or is about to alert) the contact.
        case contactAlerted
    }

    public func phase(at now: Date) -> Phase {
        let remaining = expectedArrival.timeIntervalSince(now)
        if remaining > Self.reminderLead { return .onTrack(remaining: remaining) }
        if remaining > 0 { return .dueSoon(remaining: remaining) }
        if -remaining < Self.grace { return .overdue(late: -remaining) }
        return .contactAlerted
    }

    public var reminderDate: Date { expectedArrival.addingTimeInterval(-Self.reminderLead) }
    public var alertDate: Date { expectedArrival.addingTimeInterval(Self.grace) }

    /// Adds ten minutes, never beyond `maxDuration` after the start.
    public mutating func extend(now: Date = Date()) {
        let base = max(expectedArrival, now)
        expectedArrival = min(base.addingTimeInterval(Self.extensionStep), startedAt.addingTimeInterval(Self.maxDuration))
    }

    public var canExtend: Bool {
        expectedArrival < startedAt.addingTimeInterval(Self.maxDuration)
    }
}

public enum WalkStatus: String, Codable, Sendable {
    case active
    case arrived
    case alerted
    case cancelled
}

public struct WalkSession: Hashable, Codable, Sendable, Identifiable {
    public let id: UUID
    /// Link the contact opens to follow the walk.
    public let shareURL: URL
    public var plan: WalkPlan
    public var status: WalkStatus

    public init(id: UUID, shareURL: URL, plan: WalkPlan, status: WalkStatus) {
        self.id = id
        self.shareURL = shareURL
        self.plan = plan
        self.status = status
    }
}
