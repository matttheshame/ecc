import BruskCore
import Foundation

/// The signed-in user, as far as the app needs to know. The e-mail is only ever shown
/// to its owner (Settings → Account).
public struct AuthSession: Hashable, Sendable {
    public let userID: UUID
    public let email: String?

    public init(userID: UUID, email: String?) {
        self.userID = userID
        self.email = email
    }
}

/// Errors surfaced to the UI. Each maps to a localized message key.
public enum BackendError: Error, Hashable, Sendable {
    case notSignedIn
    case invalidCode
    case rateLimited
    case outsideBrussels
    case textRejected
    case tooFarToConfirm
    case alreadyConfirmed
    case invalidTime
    case notFound
    case network
    case notConfigured
    case server(String)

    public var messageKey: String {
        switch self {
        case .notSignedIn: "error.notSignedIn"
        case .invalidCode: "error.invalidCode"
        case .rateLimited: "error.rateLimited"
        case .outsideBrussels: "error.outsideBrussels"
        case .textRejected: "error.textRejected"
        case .tooFarToConfirm: "error.tooFarToConfirm"
        case .alreadyConfirmed: "error.alreadyConfirmed"
        case .invalidTime: "report.validation.tooOld"
        case .notFound: "error.notFound"
        case .network: "error.network"
        case .notConfigured: "error.notConfigured"
        case .server: "error.generic"
        }
    }

    /// Maps the `BRUSK_*` error codes raised by the Postgres functions.
    public static func fromServerMessage(_ message: String) -> BackendError {
        let table: [(String, BackendError)] = [
            ("BRUSK_RATE_LIMIT", .rateLimited),
            ("BRUSK_OUTSIDE_BRUSSELS", .outsideBrussels),
            ("BRUSK_TEXT_POLICY", .textRejected),
            ("BRUSK_TOO_FAR", .tooFarToConfirm),
            ("BRUSK_ALREADY_CONFIRMED", .alreadyConfirmed),
            ("BRUSK_NOT_AUTHENTICATED", .notSignedIn),
            ("BRUSK_INVALID_TIME", .invalidTime),
            ("BRUSK_NOT_FOUND", .notFound),
            ("BRUSK_INVALID_PHOTO", .server("BRUSK_INVALID_PHOTO")),
        ]
        return table.first { message.contains($0.0) }?.1 ?? .server(message)
    }
}

/// Everything the app asks of the server. View models depend on this protocol only,
/// so every screen runs against `DemoBackend` in previews and when no keys are set.
public protocol Backend: Sendable {
    /// True when running on local demo data.
    var isDemo: Bool { get }

    // MARK: Auth (e-mail one-time code only — spec §4.1)
    func currentSession() async -> AuthSession?
    func sendCode(to email: String, language: LanguageCode) async throws
    func verifyCode(_ code: String, email: String) async throws -> AuthSession
    func signOut() async throws
    func deleteAccount() async throws
    func setLanguage(_ language: LanguageCode) async throws

    // MARK: Map
    func zones(matching filter: ZoneFilter) async throws -> [Zone]
    func zoneDetail(_ id: ZoneID) async throws -> ZoneDetail
    func flagZone(_ id: ZoneID, reason: FlagReason) async throws

    // MARK: Reports
    func submit(_ report: ReportSubmission) async throws -> SubmittedReport
    func myReports() async throws -> [MyReport]
    func deleteReport(_ id: UUID) async throws
    func nearbyReports(around coordinate: GeoCoordinate) async throws -> [NearbyReport]
    func confirm(_ reportID: UUID, from coordinate: GeoCoordinate) async throws
    func myTrust() async throws -> TrustInfo

    // MARK: Walking home alone
    func startWalk(contactEmail: String, plan: WalkPlan, language: LanguageCode) async throws -> WalkSession
    func updateWalkPosition(_ id: UUID, coordinate: GeoCoordinate) async throws
    func extendWalk(_ id: UUID, until expectedArrival: Date) async throws
    func endWalk(_ id: UUID, arrived: Bool) async throws
}
