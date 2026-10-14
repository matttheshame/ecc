import BruskBackend
import BruskCore
import MapKit
import Observation
import SwiftUI

/// The zones under a tap. Several categories can share one cell; the sheet lets the
/// user switch between them.
struct ZoneSelection: Identifiable, Equatable {
    let zones: [Zone]
    var current: Zone

    var id: String { "\(current.id.hexI)/\(current.id.hexJ)" }
}

@MainActor
@Observable
final class MapViewModel {
    enum LoadState: Equatable {
        case idle
        case loading
        case loaded
        /// Network unavailable: showing the cache saved at this date.
        case offline(Date)
        case failed(BackendError)
    }

    private(set) var zones: [Zone] = []
    private(set) var state: LoadState = .idle
    private(set) var filter = ZoneFilter()
    var selection: ZoneSelection?
    var camera: MapCameraPosition = .region(MapViewModel.brusselsRegion)
    /// Category glyphs on zones once zoomed in: identity never relies on colour alone.
    var showsGlyphs = false
    var isShowingList = false

    private let backend: any Backend
    private let store: LocalStore
    private var loadTask: Task<Void, Never>?

    static let brusselsRegion = MKCoordinateRegion(
        center: Brussels.center.clCoordinate,
        span: MKCoordinateSpan(latitudeDelta: Brussels.regionSpan.latitude, longitudeDelta: Brussels.regionSpan.longitude)
    )

    init(backend: any Backend, store: LocalStore) {
        self.backend = backend
        self.store = store
    }

    var isDemo: Bool { backend.isDemo }

    // MARK: Loading

    func load() async {
        if let cached = store.cachedZones(for: filter), zones.isEmpty || state != .loaded {
            zones = cached.zones
        }
        state = .loading
        do {
            let fresh = try await backend.zones(matching: filter)
            guard !Task.isCancelled else { return }
            zones = fresh
            store.cache(fresh, for: filter)
            state = .loaded
        } catch let error as BackendError {
            guard !Task.isCancelled else { return }
            if error == .network, let cached = store.cachedZones(for: filter) {
                zones = cached.zones
                state = .offline(cached.fetchedAt)
            } else {
                state = .failed(error)
            }
        } catch {
            state = .failed(.server(String(describing: error)))
        }
    }

    private func reload() {
        loadTask?.cancel()
        loadTask = Task { await load() }
    }

    // MARK: Filters

    func toggle(_ category: ReportCategory) {
        if filter.categories.contains(category) {
            // Never filter down to nothing: an empty map looks broken.
            guard filter.categories.count > 1 else { return }
            filter.categories.remove(category)
        } else {
            filter.categories.insert(category)
        }
        reload()
    }

    func setPeriod(_ period: Period) {
        guard filter.period != period else { return }
        filter.period = period
        reload()
    }

    func setCommune(_ code: String?) {
        guard filter.communeCode != code else { return }
        filter.communeCode = code
        reload()
        if let code, let center = zones.first(where: { $0.communeCode == code })?.center {
            camera = .region(MKCoordinateRegion(center: center.clCoordinate, latitudinalMeters: 3_000, longitudinalMeters: 3_000))
        }
    }

    // MARK: Selection

    func select(at coordinate: GeoCoordinate) {
        let hits = zones
            .filter { Geometry.contains(coordinate, in: $0.outline) }
            .sorted { $0.intensity > $1.intensity }
        guard let first = hits.first else {
            selection = nil
            return
        }
        selection = ZoneSelection(zones: hits, current: first)
    }

    func select(_ zone: Zone) {
        let siblings = zones.filter { $0.id.hexI == zone.id.hexI && $0.id.hexJ == zone.id.hexJ }
        selection = ZoneSelection(zones: siblings.isEmpty ? [zone] : siblings, current: zone)
        camera = .region(MKCoordinateRegion(center: zone.center.clCoordinate, latitudinalMeters: 1_200, longitudinalMeters: 1_200))
    }

    /// Opens a zone from a deep link. Widens the period if needed to find it.
    func focus(on id: ZoneID) async {
        if let zone = zones.first(where: { $0.id == id }) {
            select(zone)
            return
        }
        if filter.period != .year || !filter.categories.contains(id.category) {
            filter.period = .year
            filter.categories.insert(id.category)
            await load()
        }
        if let zone = zones.first(where: { $0.id == id }) { select(zone) }
    }

    func isSelected(_ zone: Zone) -> Bool {
        selection?.current.id == zone.id
    }

    /// Fill opacity scales with intensity inside the token's range.
    func fillOpacity(for zone: Zone) -> Double {
        let range = PaletteToken.zoneFillAlpha
        return range.lowerBound + (range.upperBound - range.lowerBound) * zone.intensity
    }

    func cameraChanged(span: MKCoordinateSpan) {
        let zoomedIn = span.latitudeDelta < 0.03
        if zoomedIn != showsGlyphs { showsGlyphs = zoomedIn }
    }
}
