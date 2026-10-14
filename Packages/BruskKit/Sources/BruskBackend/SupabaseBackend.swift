import BruskCore
import Foundation
import Supabase

#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Production backend. All writes go through Postgres functions that validate input,
/// enforce rate limits and thresholds; row-level security is on for every table.
public final class SupabaseBackend: Backend {
    public let isDemo = false

    private let client: SupabaseClient
    private let projectURL: URL
    static let photoBucket = "report-photos"

    public init(url: URL, anonKey: String) {
        projectURL = url
        #if os(Linux) || os(Android)
        // Server-side/CI builds only. The iOS app uses the SDK default (Keychain).
        client = SupabaseClient(
            supabaseURL: url, supabaseKey: anonKey,
            options: SupabaseClientOptions(auth: .init(storage: InMemoryAuthStorage()))
        )
        #else
        // Default options store the session in the Keychain.
        client = SupabaseClient(supabaseURL: url, supabaseKey: anonKey)
        #endif
    }

    // MARK: Auth

    public func currentSession() async -> AuthSession? {
        guard let session = try? await client.auth.session else { return nil }
        return AuthSession(userID: session.user.id, email: session.user.email)
    }

    public func sendCode(to email: String, language: LanguageCode) async throws {
        try await map {
            // The language is stored in user metadata so the OTP e-mail template can
            // pick French, Dutch or English (see supabase/templates/otp.html).
            try await client.auth.signInWithOTP(
                email: email,
                shouldCreateUser: true,
                data: ["language": .string(language.rawValue)]
            )
        }
    }

    public func verifyCode(_ code: String, email: String) async throws -> AuthSession {
        do {
            let response = try await client.auth.verifyOTP(email: email, token: code, type: .email)
            switch response {
            case .session(let session):
                return AuthSession(userID: session.user.id, email: session.user.email)
            case .user:
                throw BackendError.invalidCode
            }
        } catch let error as AuthError {
            if error.errorCode == .otpExpired || error.errorCode == .invalidCredentials {
                throw BackendError.invalidCode
            }
            throw BackendError.server(error.localizedDescription)
        } catch let error as BackendError {
            throw error
        } catch {
            throw Self.translate(error)
        }
    }

    public func signOut() async throws {
        try await map { try await client.auth.signOut() }
    }

    public func deleteAccount() async throws {
        // Needs the service role to remove the auth user, so it runs in an edge function.
        try await map { try await client.functions.invoke("delete-account") }
        try? await client.auth.signOut(scope: .local)
    }

    public func setLanguage(_ language: LanguageCode) async throws {
        guard await currentSession() != nil else { return }
        try await map {
            try await client.rpc("set_language", params: LanguageParams(language: language.rawValue)).execute()
            _ = try await client.auth.update(user: UserAttributes(data: ["language": .string(language.rawValue)]))
        }
    }

    // MARK: Map

    public func zones(matching filter: ZoneFilter) async throws -> [Zone] {
        try await map {
            let params = ZonesParams(
                periodDays: filter.period.days,
                categories: filter.categories.map(\.rawValue).sorted(),
                commune: filter.communeCode
            )
            let rows: [ZoneRow] = try await client.rpc("get_zones", params: params).execute().value
            return rows.map(\.zone)
        }
    }

    public func zoneDetail(_ id: ZoneID) async throws -> ZoneDetail {
        try await map {
            let params = ZoneKeyParams(category: id.category.rawValue, hexI: id.hexI, hexJ: id.hexJ)
            let row: ZoneDetailRow = try await client.rpc("zone_detail", params: params).execute().value
            return ZoneDetail(zone: row.zone.zone, weeklyCounts: row.weeklyCounts, neighbourhoodScore: row.neighbourhoodScore)
        }
    }

    public func flagZone(_ id: ZoneID, reason: FlagReason) async throws {
        try await map {
            let params = FlagParams(category: id.category.rawValue, hexI: id.hexI, hexJ: id.hexJ, reason: reason.rawValue)
            try await client.rpc("flag_zone", params: params).execute()
        }
    }

    // MARK: Reports

    public func submit(_ report: ReportSubmission) async throws -> SubmittedReport {
        guard let session = await currentSession() else { throw BackendError.notSignedIn }
        return try await map {
            var photoPath: String?
            if let jpeg = report.anonymisedPhotoJPEG {
                // Storage policy: users may only write under their own folder.
                let path = "\(session.userID.uuidString.lowercased())/\(report.id.uuidString.lowercased()).jpg"
                try await client.storage.from(Self.photoBucket).upload(
                    path, data: jpeg, options: FileOptions(contentType: "image/jpeg", upsert: false)
                )
                photoPath = path
            }
            let params = SubmitParams(
                id: report.id, category: report.category.rawValue,
                lat: report.coordinate.latitude, lon: report.coordinate.longitude,
                occurredAt: report.occurredAt, note: report.note, photoPath: photoPath
            )
            let row: SubmitRow = try await client.rpc("submit_report", params: params).execute().value
            return SubmittedReport(id: row.id, status: row.status)
        }
    }

    public func myReports() async throws -> [MyReport] {
        try await map {
            let rows: [MyReportRow] = try await client.rpc("my_reports").execute().value
            return rows.map(\.report)
        }
    }

    public func deleteReport(_ id: UUID) async throws {
        try await map { try await client.rpc("delete_my_report", params: IDParams(id: id)).execute() }
    }

    public func nearbyReports(around coordinate: GeoCoordinate) async throws -> [NearbyReport] {
        try await map {
            let params = LocationParams(lat: coordinate.latitude, lon: coordinate.longitude)
            let rows: [NearbyRow] = try await client.rpc("nearby_reports", params: params).execute().value
            return rows.map(\.report)
        }
    }

    public func confirm(_ reportID: UUID, from coordinate: GeoCoordinate) async throws {
        try await map {
            let params = ConfirmParams(reportID: reportID, lat: coordinate.latitude, lon: coordinate.longitude)
            try await client.rpc("confirm_report", params: params).execute()
        }
    }

    public func myTrust() async throws -> TrustInfo {
        try await map {
            let row: TrustRow = try await client.rpc("my_trust").execute().value
            return TrustInfo(weight: row.trustWeight, validatedReports: row.validatedReports, usefulConfirmations: row.usefulConfirmations)
        }
    }

    // MARK: Walking home alone

    public func startWalk(contactEmail: String, plan: WalkPlan, language: LanguageCode) async throws -> WalkSession {
        try await map {
            let params = WalkStartParams(contactEmail: contactEmail, expectedArrival: plan.expectedArrival, language: language.rawValue)
            let row: WalkStartRow = try await client.rpc("start_walk", params: params).execute().value
            return WalkSession(id: row.id, shareURL: walkViewURL(token: row.shareToken), plan: plan, status: .active)
        }
    }

    public func updateWalkPosition(_ id: UUID, coordinate: GeoCoordinate) async throws {
        try await map {
            try await client.rpc("walk_ping", params: WalkPingParams(id: id, lat: coordinate.latitude, lon: coordinate.longitude)).execute()
        }
    }

    public func extendWalk(_ id: UUID, until expectedArrival: Date) async throws {
        try await map {
            try await client.rpc("walk_extend", params: WalkExtendParams(id: id, expectedArrival: expectedArrival)).execute()
        }
    }

    public func endWalk(_ id: UUID, arrived: Bool) async throws {
        try await map {
            try await client.rpc("walk_end", params: WalkEndParams(id: id, arrived: arrived)).execute()
        }
    }

    // MARK: Helpers

    /// Public page the contact opens. Served by the `walk-view` edge function.
    func walkViewURL(token: String) -> URL {
        var components = URLComponents(url: projectURL.appendingPathComponent("functions/v1/walk-view"), resolvingAgainstBaseURL: false)!
        components.queryItems = [URLQueryItem(name: "t", value: token)]
        return components.url!
    }

    private func map<T>(_ body: () async throws -> T) async throws -> T {
        do {
            return try await body()
        } catch {
            throw Self.translate(error)
        }
    }

    static func translate(_ error: Error) -> BackendError {
        switch error {
        case let error as BackendError: error
        case let error as PostgrestError: BackendError.fromServerMessage(error.message)
        case is URLError: .network
        default: .server(String(describing: error))
        }
    }
}

#if os(Linux) || os(Android)
/// Session storage for non-Apple builds (unit tests on Linux). Never used on iOS.
final class InMemoryAuthStorage: AuthLocalStorage, @unchecked Sendable {
    private let lock = NSLock()
    private var values: [String: Data] = [:]

    func store(key: String, value: Data) throws { lock.withLock { values[key] = value } }
    func retrieve(key: String) throws -> Data? { lock.withLock { values[key] } }
    func remove(key: String) throws { lock.withLock { values[key] = nil } }
}
#endif
