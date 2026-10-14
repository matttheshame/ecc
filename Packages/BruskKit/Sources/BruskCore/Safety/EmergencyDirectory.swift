import Foundation

/// Spec annex B: every number must be confirmed with the organisation before
/// publication. Entries marked `.toVerify` are hidden in Release builds and shown
/// with a visible "to verify" badge in Debug builds, so an unchecked number can never
/// ship by accident.
public enum Verification: String, Sendable {
    case verified
    case toVerify
}

public struct EmergencyContact: Hashable, Identifiable, Sendable {
    public enum Kind: String, Sendable {
        case emergency
        case police
        case support
    }

    public let id: String
    public let kind: Kind
    public let titleKey: String
    public let detailKey: String
    /// Digits only, as dialled (`tel:`). Nil while the number is unknown.
    public let phone: String?
    public let verification: Verification

    public init(id: String, kind: Kind, titleKey: String, detailKey: String, phone: String?, verification: Verification) {
        self.id = id
        self.kind = kind
        self.titleKey = titleKey
        self.detailKey = detailKey
        self.phone = phone
        self.verification = verification
    }

    public var telURL: URL? { phone.flatMap { URL(string: "tel:\($0)") } }

    /// Number grouped for reading, e.g. "0800 98 100".
    public var displayPhone: String? {
        guard let phone else { return nil }
        if phone.count <= 4 { return phone }
        if phone.hasPrefix("0800"), phone.count == 9 {
            let d = Array(phone)
            return "\(String(d[0..<4])) \(String(d[4..<6])) \(String(d[6..<9]))"
        }
        return phone
    }
}

public enum EmergencyDirectory {
    /// 112 and 101 are the statutory Belgian numbers. Still listed for a final check in HUMAN-WORK.md.
    public static let emergency = EmergencyContact(
        id: "112", kind: .emergency, titleKey: "help.112.title", detailKey: "help.112.detail",
        phone: "112", verification: .verified
    )

    public static let police = EmergencyContact(
        id: "101", kind: .police, titleKey: "help.101.title", detailKey: "help.101.detail",
        phone: "101", verification: .verified
    )

    /// Support lines from spec annex B. TO VERIFY before publication.
    public static let support: [EmergencyContact] = [
        EmergencyContact(
            id: "cpvs", kind: .support, titleKey: "help.contact.cpvs.title", detailKey: "help.contact.cpvs.detail",
            phone: nil, verification: .toVerify
        ),
        EmergencyContact(
            id: "victim-support", kind: .support, titleKey: "help.contact.victims.title", detailKey: "help.contact.victims.detail",
            phone: nil, verification: .toVerify
        ),
        EmergencyContact(
            id: "sos-viol", kind: .support, titleKey: "help.contact.sosViol.title", detailKey: "help.contact.sosViol.detail",
            phone: "080098100", verification: .toVerify
        ),
        EmergencyContact(
            id: "violences-conjugales", kind: .support, titleKey: "help.contact.domestic.title", detailKey: "help.contact.domestic.detail",
            phone: "080030030", verification: .toVerify
        ),
        EmergencyContact(
            id: "1712", kind: .support, titleKey: "help.contact.1712.title", detailKey: "help.contact.1712.detail",
            phone: "1712", verification: .toVerify
        ),
    ]

    /// Contacts that may be displayed in this build.
    public static func visibleSupport(includeUnverified: Bool) -> [EmergencyContact] {
        support.filter { includeUnverified || $0.verification == .verified }
    }
}
