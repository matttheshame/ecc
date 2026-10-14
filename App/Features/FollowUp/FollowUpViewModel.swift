import BruskBackend
import BruskCore
import Observation
import SwiftUI

@MainActor
@Observable
final class FollowUpViewModel {
    enum NearbyState: Equatable {
        case idle
        case loading
        case loaded
        case needsLocation
        case failed(BackendError)
    }

    private(set) var reports: [MyReport] = []
    private(set) var isLoadingReports = false
    private(set) var reportsError: BackendError?
    private(set) var nearby: [NearbyReport] = []
    private(set) var nearbyState: NearbyState = .idle
    private(set) var confirming: Set<UUID> = []
    private(set) var justConfirmed: Set<UUID> = []
    private(set) var confirmError: BackendError?
    /// Incremented on each successful confirmation (drives the success haptic).
    private(set) var confirmations = 0

    private let environment: AppEnvironment

    init(environment: AppEnvironment) {
        self.environment = environment
    }

    var openReports: [MyReport] { reports.filter { $0.status.isOpen } }
    var resolvedReports: [MyReport] { reports.filter { !$0.status.isOpen } }

    func load() async {
        reports = environment.store.reports()
        guard environment.session.isSignedIn else { return }
        async let mine: Void = loadMine()
        async let around: Void = loadNearby()
        _ = await (mine, around)
    }

    private func loadMine() async {
        isLoadingReports = true
        defer { isLoadingReports = false }
        do {
            let fresh = try await environment.backend.myReports()
            environment.store.merge(fresh)
            reports = environment.store.reports()
            reportsError = nil
        } catch let error as BackendError {
            reportsError = error
        } catch {
            reportsError = .server(String(describing: error))
        }
    }

    func loadNearby() async {
        nearbyState = .loading
        guard let here = await environment.location.currentCoordinate() else {
            nearbyState = .needsLocation
            return
        }
        do {
            nearby = try await environment.backend.nearbyReports(around: here)
            nearbyState = .loaded
        } catch let error as BackendError {
            nearbyState = .failed(error)
        } catch {
            nearbyState = .failed(.server(String(describing: error)))
        }
    }

    /// One-tap confirmation (spec §5 écran 3). Each confirmation strengthens the
    /// trust score of everyone involved (server side).
    func confirm(_ report: NearbyReport) async {
        guard let here = await environment.location.currentCoordinate() else {
            nearbyState = .needsLocation
            return
        }
        confirming.insert(report.id)
        confirmError = nil
        defer { confirming.remove(report.id) }
        do {
            try await environment.backend.confirm(report.id, from: here)
            justConfirmed.insert(report.id)
            confirmations += 1
            try? await Task.sleep(for: .seconds(1.2))
            nearby.removeAll { $0.id == report.id }
            justConfirmed.remove(report.id)
        } catch let error as BackendError {
            confirmError = error
            if error == .alreadyConfirmed { nearby.removeAll { $0.id == report.id } }
        } catch {
            confirmError = .server(String(describing: error))
        }
    }

    func delete(_ report: MyReport) async -> Bool {
        do {
            try await environment.backend.deleteReport(report.id)
            environment.store.delete(report.id)
            reports.removeAll { $0.id == report.id }
            return true
        } catch {
            return false
        }
    }
}
