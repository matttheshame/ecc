import Foundation

/// A WGS84 coordinate. Platform-neutral stand-in for `CLLocationCoordinate2D`.
public struct GeoCoordinate: Hashable, Codable, Sendable {
    public var latitude: Double
    public var longitude: Double

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    /// Great-circle distance in metres (haversine).
    public func distance(to other: GeoCoordinate) -> Double {
        let r = 6_371_000.0
        let φ1 = latitude * .pi / 180, φ2 = other.latitude * .pi / 180
        let Δφ = (other.latitude - latitude) * .pi / 180
        let Δλ = (other.longitude - longitude) * .pi / 180
        let a = sin(Δφ / 2) * sin(Δφ / 2) + cos(φ1) * cos(φ2) * sin(Δλ / 2) * sin(Δλ / 2)
        return 2 * r * atan2(sqrt(a), sqrt(1 - a))
    }
}

public enum Brussels {
    /// Grand-Place, the default camera centre.
    public static let center = GeoCoordinate(latitude: 50.8467, longitude: 4.3525)

    /// Bounding box of the Brussels-Capital Region with a small margin. Reports outside
    /// are rejected (the server applies the same box).
    public static let minLatitude = 50.76
    public static let maxLatitude = 50.92
    public static let minLongitude = 4.24
    public static let maxLongitude = 4.49

    public static func contains(_ c: GeoCoordinate) -> Bool {
        (minLatitude...maxLatitude).contains(c.latitude) && (minLongitude...maxLongitude).contains(c.longitude)
    }

    /// Span (in degrees) that frames the whole region on a phone screen.
    public static let regionSpan = (latitude: 0.14, longitude: 0.20)
}

public enum Geometry {
    /// Ray-casting point-in-polygon test. Polygon is a closed or open ring of vertices.
    public static func contains(_ point: GeoCoordinate, in polygon: [GeoCoordinate]) -> Bool {
        guard polygon.count >= 3 else { return false }
        var inside = false
        var j = polygon.count - 1
        for i in polygon.indices {
            let pi = polygon[i], pj = polygon[j]
            let crosses = (pi.latitude > point.latitude) != (pj.latitude > point.latitude)
            if crosses {
                let x = (pj.longitude - pi.longitude) * (point.latitude - pi.latitude) / (pj.latitude - pi.latitude) + pi.longitude
                if point.longitude < x { inside.toggle() }
            }
            j = i
        }
        return inside
    }

    /// Arithmetic centre of a ring's vertices (good enough for small convex cells).
    public static func centroid(of polygon: [GeoCoordinate]) -> GeoCoordinate? {
        guard !polygon.isEmpty else { return nil }
        let ring = polygon.count > 1 && polygon.first == polygon.last ? Array(polygon.dropLast()) : polygon
        let lat = ring.map(\.latitude).reduce(0, +) / Double(ring.count)
        let lon = ring.map(\.longitude).reduce(0, +) / Double(ring.count)
        return GeoCoordinate(latitude: lat, longitude: lon)
    }

    /// Flat-topped hexagon around a centre, for demo data and previews only.
    /// Production outlines come from PostGIS.
    public static func hexagon(around center: GeoCoordinate, edgeMeters: Double) -> [GeoCoordinate] {
        let metersPerDegreeLat = 111_320.0
        let metersPerDegreeLon = 111_320.0 * cos(center.latitude * .pi / 180)
        return (0..<6).map { k in
            let angle = Double(k) * .pi / 3
            return GeoCoordinate(
                latitude: center.latitude + edgeMeters * sin(angle) / metersPerDegreeLat,
                longitude: center.longitude + edgeMeters * cos(angle) / metersPerDegreeLon
            )
        }
    }

    /// Rounds a distance for display so it never pinpoints a location ("≈ 250 m").
    public static func roundedDistance(_ meters: Double) -> Int {
        let step = meters < 1000 ? 50.0 : 100.0
        return max(Int(step), Int((meters / step).rounded() * step))
    }
}
