import BruskCore
import Foundation
import Testing
@testable import BruskBackend

@Suite("Backend")
struct BackendTests {
    @Test("Server error codes map to user-facing errors")
    func errorMapping() {
        #expect(BackendError.fromServerMessage("BRUSK_RATE_LIMIT: 10 reports per day") == .rateLimited)
        #expect(BackendError.fromServerMessage("BRUSK_TEXT_POLICY") == .textRejected)
        #expect(BackendError.fromServerMessage("BRUSK_INVALID_TIME") == .invalidTime)
        #expect(BackendError.fromServerMessage("BRUSK_NOT_FOUND") == .notFound)
        #expect(BackendError.fromServerMessage("boom") == .server("boom"))
    }

    @Test("Zone rows decode from the get_zones JSON shape")
    func decodeZone() throws {
        let json = """
        [{"category":"cleanliness","hex_i":12,"hex_j":-34,
          "outline":{"type":"Polygon","coordinates":[[[4.35,50.84],[4.36,50.84],[4.36,50.85],[4.35,50.84]]]},
          "center_lat":50.845,"center_lon":4.355,"confirmed_count":5,"intensity":0.5,"trend":1,
          "unresolved_since":"2026-10-01T10:00:00Z","resolved_count":2,"latest_at":"2026-10-13T08:00:00Z",
          "commune_code":"21004"}]
        """
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let rows = try decoder.decode([ZoneRow].self, from: Data(json.utf8))
        let zone = try #require(rows.first?.zone)
        #expect(zone.id == ZoneID(category: .cleanliness, hexI: 12, hexJ: -34))
        #expect(zone.outline.first == GeoCoordinate(latitude: 50.84, longitude: 4.35))
        #expect(zone.trend == .worsening)
        #expect(zone.communeCode == "21004")
    }

    @Test("Demo backend: sign-in, submit, confirm")
    func demoFlow() async throws {
        let backend = DemoBackend(latency: .zero)
        await #expect(throws: BackendError.notSignedIn) { try await backend.myReports() }
        await #expect(throws: BackendError.invalidCode) { try await backend.verifyCode("12", email: "a@b.be") }
        _ = try await backend.verifyCode("482913", email: "a@b.be")
        let before = try await backend.myReports().count
        let result = try await backend.submit(ReportSubmission(category: .road, coordinate: Brussels.center, occurredAt: Date(), note: nil, anonymisedPhotoJPEG: nil))
        #expect(result.status == .pending)
        #expect(try await backend.myReports().count == before + 1)
        await #expect(throws: BackendError.outsideBrussels) {
            try await backend.submit(ReportSubmission(category: .road, coordinate: GeoCoordinate(latitude: 48.85, longitude: 2.35), occurredAt: Date(), note: nil, anonymisedPhotoJPEG: nil))
        }
        let nearby = try await backend.nearbyReports(around: Brussels.center)
        let first = try #require(nearby.first)
        try await backend.confirm(first.id, from: Brussels.center)
        #expect(try await backend.nearbyReports(around: Brussels.center).count == nearby.count - 1)
        #expect(try await backend.myTrust().usefulConfirmations == 1)
    }

    @Test("Demo zones respect filters")
    func demoFilter() async throws {
        let backend = DemoBackend(latency: .zero)
        let all = try await backend.zones(matching: ZoneFilter(period: .year))
        let road = try await backend.zones(matching: ZoneFilter(categories: [.road], period: .year))
        let week = try await backend.zones(matching: ZoneFilter(period: .week))
        let ixelles = try await backend.zones(matching: ZoneFilter(period: .year, communeCode: "21009"))
        #expect(road.allSatisfy { $0.category == .road } && !road.isEmpty)
        #expect(week.count < all.count)
        #expect(ixelles.allSatisfy { $0.communeCode == "21009" } && !ixelles.isEmpty)
        #expect(all.allSatisfy { Brussels.contains($0.center) })
    }

    @Test("Photo paths match the storage policy and submit_report pattern")
    func photoPath() {
        let user = UUID(uuidString: "6F9619FF-8B86-D011-B42D-00C04FC964FF")!
        let report = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let path = SupabaseBackend.photoPath(user: user, report: report)
        #expect(path == "6f9619ff-8b86-d011-b42d-00c04fc964ff/00000000-0000-4000-8000-000000000001.jpg")
        #expect(path.range(of: #"^[0-9a-f-]{36}/[0-9a-f-]{36}\.jpg$"#, options: .regularExpression) != nil)
    }

    @Test("Walk view URL points at the edge function")
    func walkURL() {
        let backend = SupabaseBackend(url: URL(string: "https://abc.supabase.co")!, anonKey: "public-anon-key")
        #expect(backend.walkViewURL(token: "tok").absoluteString == "https://abc.supabase.co/functions/v1/walk-view?t=tok")
    }
}
