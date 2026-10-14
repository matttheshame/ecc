import BruskCore
import Foundation

/// Local, in-memory backend used for SwiftUI previews and when the app runs without
/// Supabase keys. The UI shows a "demo data" marker whenever this is active, so fictional
/// zones can never be mistaken for real reports about real streets.
public actor DemoBackend: Backend {
    public nonisolated let isDemo = true

    private var session: AuthSession?
    private var reports: [MyReport]
    private var nearby: [NearbyReport]
    private var trust = TrustInfo(weight: 0.30, validatedReports: 0, usefulConfirmations: 0)
    private let now: Date
    /// Simulated latency so loading states are visible in demo mode.
    private let latency: Duration

    public init(signedIn: Bool = false, now: Date = Date(), latency: Duration = .milliseconds(350)) {
        self.now = now
        self.latency = latency
        session = signedIn ? AuthSession(userID: UUID(), email: "demo@example.org") : nil
        reports = DemoData.myReports(now: now)
        nearby = DemoData.nearby(now: now)
    }

    // MARK: Auth

    public func currentSession() async -> AuthSession? { session }

    public func sendCode(to email: String, language: LanguageCode) async throws {
        try await pause()
        guard email.contains("@") else { throw BackendError.server("invalid email") }
    }

    public func verifyCode(_ code: String, email: String) async throws -> AuthSession {
        try await pause()
        // Demo rule: any 6-digit code except 000000 signs in.
        guard code.count == 6, code.allSatisfy(\.isNumber), code != "000000" else { throw BackendError.invalidCode }
        let new = AuthSession(userID: UUID(), email: email)
        session = new
        return new
    }

    public func signOut() async throws { session = nil }

    public func deleteAccount() async throws {
        try await pause()
        session = nil
        reports = []
    }

    public func setLanguage(_ language: LanguageCode) async throws {}

    // MARK: Map

    public func zones(matching filter: ZoneFilter) async throws -> [Zone] {
        try await pause()
        let cutoff = now.addingTimeInterval(-Double(filter.period.days) * 86_400)
        return DemoData.zones(now: now).filter {
            filter.categories.contains($0.category)
                && $0.latestAt >= cutoff
                && (filter.communeCode == nil || $0.communeCode == filter.communeCode)
        }
    }

    public func zoneDetail(_ id: ZoneID) async throws -> ZoneDetail {
        try await pause()
        guard let zone = DemoData.zones(now: now).first(where: { $0.id == id }) else {
            throw BackendError.server("unknown zone")
        }
        let seed = abs(id.hexI &* 31 &+ id.hexJ)
        let weekly = (0..<8).map { week in max(0, (seed + week * 7) % 6 + (week > 4 ? zone.trend.rawValue : 0)) }
        return ZoneDetail(zone: zone, weeklyCounts: weekly, neighbourhoodScore: 55 + seed % 40)
    }

    public func flagZone(_ id: ZoneID, reason: FlagReason) async throws {
        try await requireSession()
        try await pause()
    }

    // MARK: Reports

    public func submit(_ report: ReportSubmission) async throws -> SubmittedReport {
        try await requireSession()
        try await pause()
        let issues = ReportRules.validate(coordinate: report.coordinate, occurredAt: report.occurredAt, note: report.note, now: Date())
        if issues.contains(.outsideBrussels) { throw BackendError.outsideBrussels }
        if issues.contains(.noteRejected) { throw BackendError.textRejected }
        let stored = MyReport(
            id: report.id, category: report.category, coordinate: report.coordinate,
            occurredAt: report.occurredAt, createdAt: Date(), status: .pending, routedTo: nil,
            note: report.note, hasPhoto: report.anonymisedPhotoJPEG != nil, confirmations: 0
        )
        reports.insert(stored, at: 0)
        return SubmittedReport(id: stored.id, status: .pending)
    }

    public func myReports() async throws -> [MyReport] {
        try await requireSession()
        try await pause()
        return reports
    }

    public func deleteReport(_ id: UUID) async throws {
        try await requireSession()
        reports.removeAll { $0.id == id }
    }

    public func nearbyReports(around coordinate: GeoCoordinate) async throws -> [NearbyReport] {
        try await requireSession()
        try await pause()
        return nearby
    }

    public func confirm(_ reportID: UUID, from coordinate: GeoCoordinate) async throws {
        try await requireSession()
        try await pause()
        guard nearby.contains(where: { $0.id == reportID }) else { throw BackendError.alreadyConfirmed }
        nearby.removeAll { $0.id == reportID }
        trust = TrustInfo(weight: min(1, trust.weight + 0.05), validatedReports: trust.validatedReports, usefulConfirmations: trust.usefulConfirmations + 1)
    }

    public func myTrust() async throws -> TrustInfo {
        try await requireSession()
        return trust
    }

    // MARK: Walk

    public func startWalk(contactEmail: String, plan: WalkPlan, language: LanguageCode) async throws -> WalkSession {
        try await requireSession()
        try await pause()
        return WalkSession(id: UUID(), shareURL: URL(string: "https://\(DeepLink.universalHost)/walk/demo")!, plan: plan, status: .active)
    }

    public func updateWalkPosition(_ id: UUID, coordinate: GeoCoordinate) async throws {}
    public func extendWalk(_ id: UUID, until expectedArrival: Date) async throws {}
    public func endWalk(_ id: UUID, arrived: Bool) async throws {}

    // MARK: Helpers

    private func requireSession() async throws {
        if session == nil { throw BackendError.notSignedIn }
    }

    private func pause() async throws {
        if latency > .zero { try await Task.sleep(for: latency) }
    }
}

/// Fictional sample data. Locations are spread across the region on purpose so that no
/// single street or neighbourhood is singled out in screenshots.
public enum DemoData {
    struct Seed {
        let category: ReportCategory
        let lat: Double
        let lon: Double
        let count: Int
        let daysAgo: Int
        let unresolvedDays: Int?
        let resolved: Int
        let trend: Trend
        let commune: String
    }

    static let seeds: [Seed] = [
        Seed(category: .road, lat: 50.8274, lon: 4.3724, count: 9, daysAgo: 1, unresolvedDays: 12, resolved: 2, trend: .worsening, commune: "21009"),
        Seed(category: .road, lat: 50.8381, lon: 4.3627, count: 6, daysAgo: 3, unresolvedDays: 21, resolved: 0, trend: .stable, commune: "21009"),
        Seed(category: .road, lat: 50.8610, lon: 4.3880, count: 4, daysAgo: 6, unresolvedDays: 8, resolved: 1, trend: .improving, commune: "21015"),
        Seed(category: .road, lat: 50.8040, lon: 4.3410, count: 5, daysAgo: 20, unresolvedDays: 40, resolved: 3, trend: .stable, commune: "21007"),
        Seed(category: .cleanliness, lat: 50.8483, lon: 4.3497, count: 11, daysAgo: 0, unresolvedDays: 5, resolved: 6, trend: .improving, commune: "21004"),
        Seed(category: .cleanliness, lat: 50.8330, lon: 4.3450, count: 7, daysAgo: 2, unresolvedDays: 12, resolved: 1, trend: .worsening, commune: "21013"),
        Seed(category: .cleanliness, lat: 50.8550, lon: 4.3320, count: 5, daysAgo: 9, unresolvedDays: nil, resolved: 5, trend: .improving, commune: "21012"),
        Seed(category: .cleanliness, lat: 50.8420, lon: 4.4100, count: 4, daysAgo: 40, unresolvedDays: 60, resolved: 0, trend: .stable, commune: "21018"),
        Seed(category: .insecurity, lat: 50.8445, lon: 4.3570, count: 4, daysAgo: 2, unresolvedDays: nil, resolved: 0, trend: .stable, commune: "21004"),
        Seed(category: .insecurity, lat: 50.8215, lon: 4.3990, count: 3, daysAgo: 15, unresolvedDays: nil, resolved: 0, trend: .improving, commune: "21002"),
        Seed(category: .harassment, lat: 50.8512, lon: 4.3600, count: 5, daysAgo: 1, unresolvedDays: nil, resolved: 0, trend: .worsening, commune: "21004"),
        Seed(category: .harassment, lat: 50.8300, lon: 4.3560, count: 3, daysAgo: 25, unresolvedDays: nil, resolved: 0, trend: .stable, commune: "21009"),
    ]

    public static func zones(now: Date) -> [Zone] {
        let maxCount = Double(seeds.map(\.count).max() ?? 1)
        return seeds.enumerated().map { index, seed in
            let center = GeoCoordinate(latitude: seed.lat, longitude: seed.lon)
            return Zone(
                id: ZoneID(category: seed.category, hexI: 100 + index, hexJ: -50 - index),
                outline: Geometry.hexagon(around: center, edgeMeters: 120),
                center: center,
                confirmedCount: seed.count,
                intensity: Double(seed.count) / maxCount,
                trend: seed.trend,
                unresolvedSince: seed.unresolvedDays.map { now.addingTimeInterval(-Double($0) * 86_400) },
                resolvedCount: seed.resolved,
                latestAt: now.addingTimeInterval(-Double(seed.daysAgo) * 86_400),
                communeCode: seed.commune
            )
        }
    }

    public static func myReports(now: Date) -> [MyReport] {
        [
            MyReport(
                id: UUID(), category: .road, coordinate: GeoCoordinate(latitude: 50.8276, longitude: 4.3721),
                occurredAt: now.addingTimeInterval(-12 * 86_400), createdAt: now.addingTimeInterval(-12 * 86_400),
                status: .sent, routedTo: .commune, note: nil, hasPhoto: true, confirmations: 6
            ),
            MyReport(
                id: UUID(), category: .cleanliness, coordinate: GeoCoordinate(latitude: 50.8332, longitude: 4.3452),
                occurredAt: now.addingTimeInterval(-3 * 86_400), createdAt: now.addingTimeInterval(-3 * 86_400),
                status: .confirmed, routedTo: nil, note: nil, hasPhoto: false, confirmations: 3
            ),
            MyReport(
                id: UUID(), category: .harassment, coordinate: GeoCoordinate(latitude: 50.8510, longitude: 4.3602),
                occurredAt: now.addingTimeInterval(-3_600 * 5), createdAt: now.addingTimeInterval(-3_600 * 5),
                status: .pending, routedTo: nil, note: nil, hasPhoto: false, confirmations: 1
            ),
            MyReport(
                id: UUID(), category: .cleanliness, coordinate: GeoCoordinate(latitude: 50.8552, longitude: 4.3318),
                occurredAt: now.addingTimeInterval(-30 * 86_400), createdAt: now.addingTimeInterval(-30 * 86_400),
                status: .resolved, routedTo: .bruxellesProprete, note: nil, hasPhoto: true, confirmations: 4
            ),
        ]
    }

    public static func nearby(now: Date) -> [NearbyReport] {
        [
            NearbyReport(id: UUID(), category: .cleanliness, cellCenter: GeoCoordinate(latitude: 50.8470, longitude: 4.3510), distanceMeters: 150, occurredAt: now.addingTimeInterval(-3_600 * 2), confirmations: 2),
            NearbyReport(id: UUID(), category: .road, cellCenter: GeoCoordinate(latitude: 50.8455, longitude: 4.3540), distanceMeters: 350, occurredAt: now.addingTimeInterval(-86_400), confirmations: 1),
            NearbyReport(id: UUID(), category: .harassment, cellCenter: GeoCoordinate(latitude: 50.8490, longitude: 4.3560), distanceMeters: 600, occurredAt: now.addingTimeInterval(-3_600 * 20), confirmations: 0),
        ]
    }
}
