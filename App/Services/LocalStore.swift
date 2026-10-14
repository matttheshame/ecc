import BruskCore
import Foundation
import SwiftData

/// The user's own reports, cached for instant display and offline use. The exact
/// coordinate is the user's own data; it never appears anywhere public.
@Model
final class StoredReport {
    @Attribute(.unique) var id: UUID
    var categoryRaw: String
    var latitude: Double
    var longitude: Double
    var occurredAt: Date
    var createdAt: Date
    var statusRaw: String
    var routedToRaw: String?
    var note: String?
    var confirmations: Int
    /// File name of the unblurred original in `OriginalPhotoStore`. Never uploaded
    /// (spec §5 écran 4: "la version d'origine reste uniquement sur le téléphone").
    var originalPhotoFile: String?

    init(report: MyReport, originalPhotoFile: String? = nil) {
        id = report.id
        categoryRaw = report.category.rawValue
        latitude = report.coordinate.latitude
        longitude = report.coordinate.longitude
        occurredAt = report.occurredAt
        createdAt = report.createdAt
        statusRaw = report.status.rawValue
        routedToRaw = report.routedTo?.rawValue
        note = report.note
        confirmations = report.confirmations
        self.originalPhotoFile = originalPhotoFile
    }

    var report: MyReport? {
        guard let category = ReportCategory(rawValue: categoryRaw), let status = ReportStatus(rawValue: statusRaw) else { return nil }
        return MyReport(
            id: id, category: category, coordinate: GeoCoordinate(latitude: latitude, longitude: longitude),
            occurredAt: occurredAt, createdAt: createdAt, status: status,
            routedTo: routedToRaw.flatMap(RoutingDestination.init(rawValue:)), note: note,
            hasPhoto: originalPhotoFile != nil, confirmations: confirmations
        )
    }

    func update(from report: MyReport) {
        statusRaw = report.status.rawValue
        routedToRaw = report.routedTo?.rawValue
        confirmations = report.confirmations
    }
}

/// Last zones payload per filter, so the map opens instantly and works offline.
@Model
final class CachedZones {
    @Attribute(.unique) var filterKey: String
    var payload: Data
    var fetchedAt: Date

    init(filterKey: String, payload: Data, fetchedAt: Date) {
        self.filterKey = filterKey
        self.payload = payload
        self.fetchedAt = fetchedAt
    }
}

@MainActor
final class LocalStore {
    let container: ModelContainer
    private var context: ModelContext { container.mainContext }

    init(inMemory: Bool = false) {
        let configuration = ModelConfiguration(isStoredInMemoryOnly: inMemory)
        do {
            container = try ModelContainer(for: StoredReport.self, CachedZones.self, configurations: configuration)
        } catch {
            // A corrupt cache must never block the app: fall back to memory.
            container = try! ModelContainer(for: StoredReport.self, CachedZones.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        }
    }

    // MARK: Reports

    func reports() -> [MyReport] {
        let descriptor = FetchDescriptor<StoredReport>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return ((try? context.fetch(descriptor)) ?? []).compactMap(\.report)
    }

    func stored(_ id: UUID) -> StoredReport? {
        try? context.fetch(FetchDescriptor<StoredReport>(predicate: #Predicate { $0.id == id })).first
    }

    func save(_ report: MyReport, originalPhotoFile: String?) {
        context.insert(StoredReport(report: report, originalPhotoFile: originalPhotoFile))
        try? context.save()
    }

    /// Merges the server's view. Reports deleted server-side disappear locally too.
    func merge(_ serverReports: [MyReport]) {
        let existing = (try? context.fetch(FetchDescriptor<StoredReport>())) ?? []
        let byID = Dictionary(uniqueKeysWithValues: existing.map { ($0.id, $0) })
        let serverIDs = Set(serverReports.map(\.id))
        for report in serverReports {
            if let stored = byID[report.id] {
                stored.update(from: report)
            } else {
                context.insert(StoredReport(report: report))
            }
        }
        for stored in existing where !serverIDs.contains(stored.id) {
            if let file = stored.originalPhotoFile { OriginalPhotoStore.delete(file) }
            context.delete(stored)
        }
        try? context.save()
    }

    func delete(_ id: UUID) {
        guard let stored = stored(id) else { return }
        if let file = stored.originalPhotoFile { OriginalPhotoStore.delete(file) }
        context.delete(stored)
        try? context.save()
    }

    func deleteEverything() {
        try? context.delete(model: StoredReport.self)
        try? context.delete(model: CachedZones.self)
        try? context.save()
        OriginalPhotoStore.deleteAll()
    }

    // MARK: Zones

    func cachedZones(for filter: ZoneFilter) -> (zones: [Zone], fetchedAt: Date)? {
        let key = filter.cacheKey
        guard let cached = try? context.fetch(FetchDescriptor<CachedZones>(predicate: #Predicate { $0.filterKey == key })).first,
              let zones = try? JSONDecoder().decode([Zone].self, from: cached.payload) else { return nil }
        return (zones, cached.fetchedAt)
    }

    func cache(_ zones: [Zone], for filter: ZoneFilter) {
        guard let payload = try? JSONEncoder().encode(zones) else { return }
        let key = filter.cacheKey
        if let cached = try? context.fetch(FetchDescriptor<CachedZones>(predicate: #Predicate { $0.filterKey == key })).first {
            cached.payload = payload
            cached.fetchedAt = Date()
        } else {
            context.insert(CachedZones(filterKey: key, payload: payload, fetchedAt: Date()))
        }
        try? context.save()
    }
}

/// Unblurred originals, kept only on this device for the complaint recap.
/// Encrypted at rest (complete file protection) and excluded from backups.
enum OriginalPhotoStore {
    private static var directory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        var url = base.appendingPathComponent("Originals", isDirectory: true)
        if !FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
            var values = URLResourceValues()
            values.isExcludedFromBackup = true
            try? url.setResourceValues(values)
        }
        return url
    }

    static func save(_ jpeg: Data, id: UUID) -> String? {
        let name = "\(id.uuidString).jpg"
        do {
            try jpeg.write(to: directory.appendingPathComponent(name), options: [.atomic, .completeFileProtection])
            return name
        } catch {
            return nil
        }
    }

    static func load(_ name: String) -> Data? {
        try? Data(contentsOf: directory.appendingPathComponent(name))
    }

    static func delete(_ name: String) {
        try? FileManager.default.removeItem(at: directory.appendingPathComponent(name))
    }

    static func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }
}
