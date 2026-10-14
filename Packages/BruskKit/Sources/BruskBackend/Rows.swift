import BruskCore
import Foundation

// Wire formats returned by the Postgres functions in `supabase/migrations`.
// Explicit CodingKeys: the JSON is snake_case and must not depend on decoder settings.

struct GeoJSONPolygon: Decodable {
    let coordinates: [[[Double]]]

    var ring: [GeoCoordinate] {
        (coordinates.first ?? []).compactMap { pair in
            pair.count >= 2 ? GeoCoordinate(latitude: pair[1], longitude: pair[0]) : nil
        }
    }
}

struct ZoneRow: Decodable {
    let category: ReportCategory
    let hexI: Int
    let hexJ: Int
    let outline: GeoJSONPolygon
    let centerLat: Double
    let centerLon: Double
    let confirmedCount: Int
    let intensity: Double
    let trend: Int
    let unresolvedSince: Date?
    let resolvedCount: Int
    let latestAt: Date
    let communeCode: String?

    enum CodingKeys: String, CodingKey {
        case category, outline, intensity, trend
        case hexI = "hex_i"
        case hexJ = "hex_j"
        case centerLat = "center_lat"
        case centerLon = "center_lon"
        case confirmedCount = "confirmed_count"
        case unresolvedSince = "unresolved_since"
        case resolvedCount = "resolved_count"
        case latestAt = "latest_at"
        case communeCode = "commune_code"
    }

    var zone: Zone {
        Zone(
            id: ZoneID(category: category, hexI: hexI, hexJ: hexJ),
            outline: outline.ring,
            center: GeoCoordinate(latitude: centerLat, longitude: centerLon),
            confirmedCount: confirmedCount,
            intensity: intensity,
            trend: Trend(rawValue: trend) ?? .stable,
            unresolvedSince: unresolvedSince,
            resolvedCount: resolvedCount,
            latestAt: latestAt,
            communeCode: communeCode
        )
    }
}

struct ZoneDetailRow: Decodable {
    let zone: ZoneRow
    let weeklyCounts: [Int]
    let neighbourhoodScore: Int

    enum CodingKeys: String, CodingKey {
        case zone
        case weeklyCounts = "weekly_counts"
        case neighbourhoodScore = "neighbourhood_score"
    }
}

struct MyReportRow: Decodable {
    let id: UUID
    let category: ReportCategory
    let lat: Double
    let lon: Double
    let occurredAt: Date
    let createdAt: Date
    let status: ReportStatus
    let routedTo: String?
    let note: String?
    let hasPhoto: Bool
    let confirmations: Int

    enum CodingKeys: String, CodingKey {
        case id, category, lat, lon, status, note, confirmations
        case occurredAt = "occurred_at"
        case createdAt = "created_at"
        case routedTo = "routed_to"
        case hasPhoto = "has_photo"
    }

    var report: MyReport {
        MyReport(
            id: id, category: category, coordinate: GeoCoordinate(latitude: lat, longitude: lon),
            occurredAt: occurredAt, createdAt: createdAt, status: status,
            routedTo: routedTo.flatMap(RoutingDestination.init(rawValue:)), note: note,
            hasPhoto: hasPhoto, confirmations: confirmations
        )
    }
}

struct NearbyRow: Decodable {
    let id: UUID
    let category: ReportCategory
    let centerLat: Double
    let centerLon: Double
    let distanceM: Int
    let occurredAt: Date
    let confirmations: Int

    enum CodingKeys: String, CodingKey {
        case id, category, confirmations
        case centerLat = "center_lat"
        case centerLon = "center_lon"
        case distanceM = "distance_m"
        case occurredAt = "occurred_at"
    }

    var report: NearbyReport {
        NearbyReport(
            id: id, category: category,
            cellCenter: GeoCoordinate(latitude: centerLat, longitude: centerLon),
            distanceMeters: distanceM, occurredAt: occurredAt, confirmations: confirmations
        )
    }
}

struct SubmitRow: Decodable {
    let id: UUID
    let status: ReportStatus
}

struct TrustRow: Decodable {
    let trustWeight: Double
    let validatedReports: Int
    let usefulConfirmations: Int

    enum CodingKeys: String, CodingKey {
        case trustWeight = "trust_weight"
        case validatedReports = "validated_reports"
        case usefulConfirmations = "useful_confirmations"
    }
}

struct WalkStartRow: Decodable {
    let id: UUID
    let shareToken: String

    enum CodingKeys: String, CodingKey {
        case id
        case shareToken = "share_token"
    }
}

// MARK: - Parameters

struct ZonesParams: Encodable {
    let periodDays: Int
    let categories: [String]
    let commune: String?

    enum CodingKeys: String, CodingKey {
        case periodDays = "p_period_days"
        case categories = "p_categories"
        case commune = "p_commune"
    }
}

struct ZoneKeyParams: Encodable {
    let category: String
    let hexI: Int
    let hexJ: Int

    enum CodingKeys: String, CodingKey {
        case category = "p_category"
        case hexI = "p_hex_i"
        case hexJ = "p_hex_j"
    }
}

struct FlagParams: Encodable {
    let category: String
    let hexI: Int
    let hexJ: Int
    let reason: String

    enum CodingKeys: String, CodingKey {
        case category = "p_category"
        case hexI = "p_hex_i"
        case hexJ = "p_hex_j"
        case reason = "p_reason"
    }
}

struct SubmitParams: Encodable {
    let id: UUID
    let category: String
    let lat: Double
    let lon: Double
    let occurredAt: Date
    let note: String?
    let photoPath: String?

    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case category = "p_category"
        case lat = "p_lat"
        case lon = "p_lon"
        case occurredAt = "p_occurred_at"
        case note = "p_note"
        case photoPath = "p_photo_path"
    }
}

struct IDParams: Encodable {
    let id: UUID
    enum CodingKeys: String, CodingKey { case id = "p_id" }
}

struct LocationParams: Encodable {
    let lat: Double
    let lon: Double
    enum CodingKeys: String, CodingKey {
        case lat = "p_lat"
        case lon = "p_lon"
    }
}

struct ConfirmParams: Encodable {
    let reportID: UUID
    let lat: Double
    let lon: Double
    enum CodingKeys: String, CodingKey {
        case reportID = "p_report_id"
        case lat = "p_lat"
        case lon = "p_lon"
    }
}

struct LanguageParams: Encodable {
    let language: String
    enum CodingKeys: String, CodingKey { case language = "p_language" }
}

struct WalkStartParams: Encodable {
    let contactEmail: String
    let expectedArrival: Date
    let language: String
    enum CodingKeys: String, CodingKey {
        case contactEmail = "p_contact_email"
        case expectedArrival = "p_expected_arrival"
        case language = "p_language"
    }
}

struct WalkPingParams: Encodable {
    let id: UUID
    let lat: Double
    let lon: Double
    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case lat = "p_lat"
        case lon = "p_lon"
    }
}

struct WalkExtendParams: Encodable {
    let id: UUID
    let expectedArrival: Date
    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case expectedArrival = "p_expected_arrival"
    }
}

struct WalkEndParams: Encodable {
    let id: UUID
    let arrived: Bool
    enum CodingKeys: String, CodingKey {
        case id = "p_id"
        case arrived = "p_arrived"
    }
}
