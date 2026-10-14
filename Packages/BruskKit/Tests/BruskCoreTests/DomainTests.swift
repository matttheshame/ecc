import Foundation
import Testing
@testable import BruskCore

@Suite("Domain rules")
struct DomainTests {
    @Test("Serious categories never route automatically (spec §6)")
    func seriousRouting() {
        #expect(ReportCategory.insecurity.isSerious && !ReportCategory.insecurity.allowsAutomaticRouting)
        #expect(ReportCategory.harassment.isSerious && !ReportCategory.harassment.allowsAutomaticRouting)
        #expect(ReportCategory.road.allowsAutomaticRouting)
        #expect(ReportCategory.cleanliness.allowsAutomaticRouting)
    }

    @Test("Statuses are ordered pending < confirmed < sent < resolved")
    func statusOrder() {
        #expect(ReportStatus.allCases.sorted() == [.pending, .confirmed, .sent, .resolved])
        #expect(!ReportStatus.resolved.isOpen)
    }

    @Test("19 communes with unique NIS codes and names in both languages")
    func communes() {
        #expect(Commune.all.count == 19)
        #expect(Set(Commune.all.map(\.nisCode)).count == 19)
        #expect(Commune.with(code: "21009")?.name(in: .nl) == "Elsene")
        #expect(Commune.with(code: "21009")?.name(in: .en) == "Ixelles")
        #expect(Commune.sorted(in: .nl).first?.nameNL == "Anderlecht")
    }

    @Test("Language best match")
    func language() {
        #expect(LanguageCode.bestMatch(for: ["nl-BE", "fr-BE"]) == .nl)
        #expect(LanguageCode.bestMatch(for: ["de-DE", "en-GB"]) == .en)
        #expect(LanguageCode.bestMatch(for: ["de-DE"]) == .fr)
        #expect(LanguageCode.bestMatch(for: ["fr_BE"]) == .fr)
    }

    @Test("Geometry: Brussels bounds, distance, point in hexagon")
    func geometry() {
        #expect(Brussels.contains(Brussels.center))
        #expect(!Brussels.contains(GeoCoordinate(latitude: 51.2194, longitude: 4.4025))) // Antwerp
        let d = GeoCoordinate(latitude: 50.8467, longitude: 4.3525).distance(to: GeoCoordinate(latitude: 50.8466, longitude: 4.3601))
        #expect(d > 500 && d < 560)
        let hex = Geometry.hexagon(around: Brussels.center, edgeMeters: 120)
        #expect(hex.count == 6)
        #expect(Geometry.contains(Brussels.center, in: hex))
        #expect(!Geometry.contains(GeoCoordinate(latitude: 50.8500, longitude: 4.3525), in: hex))
        let c = Geometry.centroid(of: hex)!
        #expect(c.distance(to: Brussels.center) < 1)
        #expect(Geometry.roundedDistance(12) == 50)
        #expect(Geometry.roundedDistance(274) == 250)
        #expect(Geometry.roundedDistance(1_249) == 1_200)
    }

    @Test("Report validation")
    func reportValidation() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        #expect(ReportRules.validate(coordinate: Brussels.center, occurredAt: now, note: nil, now: now).isEmpty)
        #expect(ReportRules.validate(coordinate: Brussels.center, occurredAt: now.addingTimeInterval(3_600), note: nil, now: now) == [.occurredInFuture])
        #expect(ReportRules.validate(coordinate: Brussels.center, occurredAt: now.addingTimeInterval(-8 * 86_400), note: nil, now: now) == [.occurredTooLongAgo])
        #expect(ReportRules.validate(coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35), occurredAt: now, note: nil, now: now) == [.outsideBrussels])
        #expect(ReportRules.validate(coordinate: Brussels.center, occurredAt: now, note: "Un homme barbu", now: now) == [.noteRejected])
    }

    @Test("Problem age counts calendar days")
    func problemAge() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Brussels")!
        let since = ISO8601DateFormatter().date(from: "2026-10-02T22:30:00Z")!
        let now = ISO8601DateFormatter().date(from: "2026-10-14T08:00:00Z")!
        #expect(ProblemAge.days(since: since, now: now, calendar: calendar) == 11)
        #expect(ProblemAge.days(since: now, now: since, calendar: calendar) == 0)
    }

    @Test("Trust levels")
    func trust() {
        #expect(TrustLevel(weight: 0.30) == .new)
        #expect(TrustLevel(weight: 0.60) == .established)
        #expect(TrustLevel(weight: 0.90) == .trusted)
    }

    @Test("Deep links round-trip")
    func deepLinks() {
        let id = ZoneID(category: .cleanliness, hexI: 12, hexJ: -34)
        let link = DeepLink.zone(id)
        #expect(DeepLink(url: link.shareURL) == link)
        #expect(DeepLink(url: URL(string: "brusk://zone/road/1/2")!) == .zone(ZoneID(category: .road, hexI: 1, hexJ: 2)))
        #expect(DeepLink(url: URL(string: "brusk://help")!) == .help)
        #expect(DeepLink(url: URL(string: "brusk://zone/unknown/1/2")!) == nil)
        #expect(DeepLink(url: URL(string: "https://evil.example/z/road/1/2")!) == nil)
    }

    @Test("Emergency directory: statutory numbers present, unverified hidden in release")
    func emergency() {
        #expect(EmergencyDirectory.emergency.phone == "112")
        #expect(EmergencyDirectory.police.phone == "101")
        #expect(EmergencyDirectory.visibleSupport(includeUnverified: false).allSatisfy { $0.verification == .verified })
        #expect(EmergencyDirectory.visibleSupport(includeUnverified: true).count == EmergencyDirectory.support.count)
        #expect(EmergencyDirectory.support.first { $0.id == "sos-viol" }?.displayPhone == "0800 98 100")
    }

    @Test("Walk plan phases and extension cap")
    func walk() {
        let start = Date(timeIntervalSince1970: 0)
        var plan = WalkPlan(startedAt: start, minutes: 20)
        #expect(plan.phase(at: start) == .onTrack(remaining: 1_200))
        #expect(plan.phase(at: start.addingTimeInterval(17 * 60)) == .dueSoon(remaining: 180))
        #expect(plan.phase(at: start.addingTimeInterval(22 * 60)) == .overdue(late: 120))
        #expect(plan.phase(at: start.addingTimeInterval(26 * 60)) == .contactAlerted)
        plan.extend(now: start)
        #expect(plan.expectedArrival == start.addingTimeInterval(30 * 60))
        for _ in 0..<50 { plan.extend(now: start) }
        #expect(plan.expectedArrival == start.addingTimeInterval(WalkPlan.maxDuration))
        #expect(!plan.canExtend)
    }

    @Test("Zone filter cache key is stable regardless of set order")
    func filterKey() {
        let a = ZoneFilter(categories: [.road, .harassment], period: .week, communeCode: nil)
        let b = ZoneFilter(categories: [.harassment, .road], period: .week, communeCode: nil)
        #expect(a.cacheKey == b.cacheKey)
        #expect(ZoneFilter().isDefault)
    }
}
