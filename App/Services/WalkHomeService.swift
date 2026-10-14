import BruskBackend
import BruskCore
import CoreLocation
import Foundation
import Observation
import UserNotifications

/// "Je rentre seul·e" (spec §5 écran 4). Shares the live position with one contact
/// through a private link, and the server e-mails that contact if arrival is not
/// confirmed in time (edge function `walk-watchdog`). Only the last position is kept,
/// never a trail, and it is deleted 24 h after the walk ends.
@MainActor
@Observable
final class WalkHomeService {
    enum State: Equatable {
        case idle
        case starting
        case active(WalkSession)
        case arrived
        case failed(BackendError)
    }

    private(set) var state: State = .idle
    private(set) var lastSentAt: Date?
    private let backend: any Backend
    private var updatesTask: Task<Void, Never>?
    private var backgroundActivity: CLBackgroundActivitySession?
    private static let persistenceKey = "brusk.walk.active"

    init(backend: any Backend) {
        self.backend = backend
        restore()
    }

    var activeSession: WalkSession? {
        if case .active(let session) = state { return session }
        return nil
    }

    func start(contactEmail: String, minutes: Int, language: LanguageCode) async {
        state = .starting
        let plan = WalkPlan(startedAt: Date(), minutes: minutes)
        do {
            let session = try await backend.startWalk(contactEmail: contactEmail, plan: plan, language: language)
            state = .active(session)
            persist(session)
            startLocationUpdates(for: session.id)
            await scheduleReminders(for: session.plan, language: language)
        } catch let error as BackendError {
            state = .failed(error)
        } catch {
            state = .failed(.server(String(describing: error)))
        }
    }

    func extend(language: LanguageCode) async {
        guard case .active(var session) = state, session.plan.canExtend else { return }
        session.plan.extend()
        state = .active(session)
        persist(session)
        try? await backend.extendWalk(session.id, until: session.plan.expectedArrival)
        await scheduleReminders(for: session.plan, language: language)
    }

    func confirmArrival() async {
        guard let session = activeSession else { return }
        stop()
        state = .arrived
        try? await backend.endWalk(session.id, arrived: true)
    }

    func cancel() async {
        guard let session = activeSession else { return }
        stop()
        state = .idle
        try? await backend.endWalk(session.id, arrived: false)
    }

    func reset() {
        if case .active = state { return }
        state = .idle
    }

    // MARK: Location

    private func startLocationUpdates(for id: UUID) {
        updatesTask?.cancel()
        // Keeps updates flowing with the screen locked, with the blue status-bar pill
        // telling the user their location is in use. When-in-use authorisation suffices.
        backgroundActivity = CLBackgroundActivitySession()
        let backend = backend
        updatesTask = Task { [weak self] in
            var lastSent: CLLocation?
            do {
                for try await update in CLLocationUpdate.liveUpdates(.fitness) {
                    if Task.isCancelled { break }
                    guard let location = update.location, location.horizontalAccuracy >= 0, location.horizontalAccuracy <= 150 else { continue }
                    let movedEnough = lastSent.map { location.distance(from: $0) >= 40 } ?? true
                    let stale = lastSent.map { location.timestamp.timeIntervalSince($0.timestamp) >= 45 } ?? true
                    guard movedEnough || stale else { continue }
                    try? await backend.updateWalkPosition(id, coordinate: GeoCoordinate(location.coordinate))
                    lastSent = location
                    self?.lastSentAt = Date()
                }
            } catch {}
        }
    }

    private func stop() {
        updatesTask?.cancel()
        updatesTask = nil
        backgroundActivity?.invalidate()
        backgroundActivity = nil
        UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: NotificationID.walkAll)
    }

    // MARK: Notifications

    private enum NotificationID {
        static let reminder = "brusk-walk-reminder"
        static let deadline = "brusk-walk-deadline"
        static var walkAll: [String] { [reminder, deadline] }
    }

    private func scheduleReminders(for plan: WalkPlan, language: LanguageCode) async {
        let center = UNUserNotificationCenter.current()
        _ = try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        center.removePendingNotificationRequests(withIdentifiers: NotificationID.walkAll)

        let reminder = UNMutableNotificationContent()
        reminder.title = L10n.string("notification.walk.reminder.title", language: language)
        reminder.body = L10n.string("notification.walk.reminder.body", language: language)
        reminder.sound = .default
        reminder.interruptionLevel = .timeSensitive

        let deadline = UNMutableNotificationContent()
        deadline.title = L10n.string("notification.walk.deadline.title", language: language)
        deadline.body = L10n.string("notification.walk.deadline.body", language: language)
        deadline.sound = .default
        deadline.interruptionLevel = .timeSensitive

        for (id, content, date) in [(NotificationID.reminder, reminder, plan.reminderDate), (NotificationID.deadline, deadline, plan.expectedArrival)] {
            let interval = date.timeIntervalSinceNow
            guard interval > 1 else { continue }
            let request = UNNotificationRequest(identifier: id, content: content, trigger: UNTimeIntervalNotificationTrigger(timeInterval: interval, repeats: false))
            try? await center.add(request)
        }
    }

    // MARK: Persistence (survives relaunch)

    private func persist(_ session: WalkSession) {
        if let data = try? JSONEncoder().encode(session) {
            UserDefaults.standard.set(data, forKey: Self.persistenceKey)
        }
    }

    private func restore() {
        guard let data = UserDefaults.standard.data(forKey: Self.persistenceKey),
              let session = try? JSONDecoder().decode(WalkSession.self, from: data) else { return }
        if Date() > session.plan.startedAt.addingTimeInterval(WalkPlan.maxDuration) {
            UserDefaults.standard.removeObject(forKey: Self.persistenceKey)
            return
        }
        state = .active(session)
        startLocationUpdates(for: session.id)
    }
}
