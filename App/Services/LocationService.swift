import BruskCore
import CoreLocation
import Observation

extension GeoCoordinate {
    init(_ coordinate: CLLocationCoordinate2D) {
        self.init(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    var clCoordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

/// When-in-use location only. Used to place the report pin and to list reports nearby.
/// The coordinate never leaves the device except inside a report or a confirmation.
@MainActor
@Observable
final class LocationService: NSObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private(set) var authorization: CLAuthorizationStatus
    private(set) var lastKnown: GeoCoordinate?
    private var lastFixAt: Date?

    override init() {
        authorization = manager.authorizationStatus
        super.init()
        manager.delegate = self
    }

    var isAuthorized: Bool {
        authorization == .authorizedWhenInUse || authorization == .authorizedAlways
    }

    var isDenied: Bool {
        authorization == .denied || authorization == .restricted
    }

    func requestPermission() {
        if authorization == .notDetermined { manager.requestWhenInUseAuthorization() }
    }

    /// A fresh fix (≤ 100 m accuracy), or nil after 10 s / when not authorised.
    func currentCoordinate() async -> GeoCoordinate? {
        if let lastKnown, let lastFixAt, Date().timeIntervalSince(lastFixAt) < 60 { return lastKnown }
        requestPermission()
        guard !isDenied else { return nil }
        let fix = await withTaskGroup(of: GeoCoordinate?.self) { group in
            group.addTask { await Self.firstAccurateFix() }
            group.addTask {
                try? await Task.sleep(for: .seconds(10))
                return nil
            }
            let first = await group.next() ?? nil
            group.cancelAll()
            return first
        }
        if let fix {
            lastKnown = fix
            lastFixAt = Date()
        }
        return fix
    }

    nonisolated private static func firstAccurateFix() async -> GeoCoordinate? {
        do {
            for try await update in CLLocationUpdate.liveUpdates() {
                if let location = update.location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 100 {
                    return GeoCoordinate(location.coordinate)
                }
            }
        } catch {
            return nil
        }
        return nil
    }

    nonisolated func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus
        Task { @MainActor in self.authorization = status }
    }
}

/// Street name near a coordinate, for display only ("Near Rue Neuve, Bruxelles").
/// Never sent to the server.
enum StreetNamer {
    static func streetName(near coordinate: GeoCoordinate, locale: Locale) async -> String? {
        let location = CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
        let placemarks = try? await CLGeocoder().reverseGeocodeLocation(location, preferredLocale: locale)
        guard let placemark = placemarks?.first else { return nil }
        return placemark.thoroughfare ?? placemark.subLocality ?? placemark.locality
    }
}
