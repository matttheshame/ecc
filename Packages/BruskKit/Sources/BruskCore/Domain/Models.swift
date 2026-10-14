import Foundation

/// Identifies a zone: a hexagonal cell for one category. Never identifies a person.
public struct ZoneID: Hashable, Codable, Sendable, CustomStringConvertible {
    public let category: ReportCategory
    public let hexI: Int
    public let hexJ: Int

    public init(category: ReportCategory, hexI: Int, hexJ: Int) {
        self.category = category
        self.hexI = hexI
        self.hexJ = hexJ
    }

    public var description: String { "\(category.rawValue)/\(hexI)/\(hexJ)" }
}

public enum Trend: Int, Codable, Sendable {
    case improving = -1
    case stable = 0
    case worsening = 1

    public var titleKey: String {
        switch self {
        case .improving: "trend.improving"
        case .stable: "trend.stable"
        case .worsening: "trend.worsening"
        }
    }

    public var symbolName: String {
        switch self {
        case .improving: "arrow.down.right"
        case .stable: "arrow.right"
        case .worsening: "arrow.up.right"
        }
    }
}

/// A confirmed, aggregated zone as shown on the map (spec §4.3: zones, not points).
public struct Zone: Hashable, Identifiable, Codable, Sendable {
    public let id: ZoneID
    public let outline: [GeoCoordinate]
    public let center: GeoCoordinate
    public let confirmedCount: Int
    /// 0…1, relative to the busiest visible zone. Drives fill opacity.
    public let intensity: Double
    public let trend: Trend
    /// Oldest unresolved report in the zone, if any.
    public let unresolvedSince: Date?
    public let resolvedCount: Int
    public let latestAt: Date
    public let communeCode: String?

    public init(
        id: ZoneID, outline: [GeoCoordinate], center: GeoCoordinate, confirmedCount: Int,
        intensity: Double, trend: Trend, unresolvedSince: Date?, resolvedCount: Int,
        latestAt: Date, communeCode: String?
    ) {
        self.id = id
        self.outline = outline
        self.center = center
        self.confirmedCount = confirmedCount
        self.intensity = min(max(intensity, 0), 1)
        self.trend = trend
        self.unresolvedSince = unresolvedSince
        self.resolvedCount = resolvedCount
        self.latestAt = latestAt
        self.communeCode = communeCode
    }

    public var category: ReportCategory { id.category }
}

/// Extra facts shown in the zone sheet.
public struct ZoneDetail: Hashable, Sendable {
    public let zone: Zone
    /// Reports per week, oldest first (8 values).
    public let weeklyCounts: [Int]
    /// 0…100, higher is calmer. Computed over the surrounding neighbourhood, never one street.
    public let neighbourhoodScore: Int
    /// Street name near the zone centre, from reverse geocoding (filled client-side).
    public var streetName: String?

    public init(zone: Zone, weeklyCounts: [Int], neighbourhoodScore: Int, streetName: String? = nil) {
        self.zone = zone
        self.weeklyCounts = weeklyCounts
        self.neighbourhoodScore = min(max(neighbourhoodScore, 0), 100)
        self.streetName = streetName
    }
}

/// One of the signed-in user's own reports. Only its author ever sees the exact point.
public struct MyReport: Hashable, Identifiable, Codable, Sendable {
    public let id: UUID
    public let category: ReportCategory
    public let coordinate: GeoCoordinate
    public let occurredAt: Date
    public let createdAt: Date
    public var status: ReportStatus
    public let routedTo: RoutingDestination?
    public let note: String?
    public let hasPhoto: Bool
    public let confirmations: Int

    public init(
        id: UUID, category: ReportCategory, coordinate: GeoCoordinate, occurredAt: Date,
        createdAt: Date, status: ReportStatus, routedTo: RoutingDestination?, note: String?,
        hasPhoto: Bool, confirmations: Int
    ) {
        self.id = id
        self.category = category
        self.coordinate = coordinate
        self.occurredAt = occurredAt
        self.createdAt = createdAt
        self.status = status
        self.routedTo = routedTo
        self.note = note
        self.hasPhoto = hasPhoto
        self.confirmations = confirmations
    }
}

/// A recent report nearby that the user can confirm. Carries the cell centre only.
public struct NearbyReport: Hashable, Identifiable, Codable, Sendable {
    public let id: UUID
    public let category: ReportCategory
    public let cellCenter: GeoCoordinate
    /// Already rounded server-side to 50 m.
    public let distanceMeters: Int
    /// Rounded to the hour server-side.
    public let occurredAt: Date
    public let confirmations: Int

    public init(id: UUID, category: ReportCategory, cellCenter: GeoCoordinate, distanceMeters: Int, occurredAt: Date, confirmations: Int) {
        self.id = id
        self.category = category
        self.cellCenter = cellCenter
        self.distanceMeters = distanceMeters
        self.occurredAt = occurredAt
        self.confirmations = confirmations
    }
}

/// What the client sends to create a report. The photo is already anonymised.
public struct ReportSubmission: Sendable {
    public let id: UUID
    public let category: ReportCategory
    public let coordinate: GeoCoordinate
    public let occurredAt: Date
    public let note: String?
    public let anonymisedPhotoJPEG: Data?

    public init(id: UUID = UUID(), category: ReportCategory, coordinate: GeoCoordinate, occurredAt: Date, note: String?, anonymisedPhotoJPEG: Data?) {
        self.id = id
        self.category = category
        self.coordinate = coordinate
        self.occurredAt = occurredAt
        self.note = note
        self.anonymisedPhotoJPEG = anonymisedPhotoJPEG
    }
}

public struct SubmittedReport: Hashable, Codable, Sendable {
    public let id: UUID
    public let status: ReportStatus

    public init(id: UUID, status: ReportStatus) {
        self.id = id
        self.status = status
    }
}

public enum FlagReason: String, CaseIterable, Codable, Sendable {
    case personalData = "personal_data"
    case offensive
    case wrongPlace = "wrong_place"
    case other

    public var titleKey: String {
        switch self {
        case .personalData: "flag.reason.personalData"
        case .offensive: "flag.reason.offensive"
        case .wrongPlace: "flag.reason.wrongPlace"
        case .other: "flag.reason.other"
        }
    }
}
