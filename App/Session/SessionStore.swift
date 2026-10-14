import BruskBackend
import BruskCore
import Observation
import SwiftUI

/// Browsing the map needs no account. Reporting, confirming and "walking home" do:
/// `requireSignIn` presents the e-mail code sheet and resumes the action afterwards.
@MainActor
@Observable
final class SessionStore {
    private(set) var session: AuthSession?
    private(set) var isRestoring = true
    var isPresentingSignIn = false
    private var pendingAction: (() -> Void)?
    private let backend: any Backend

    init(backend: any Backend) {
        self.backend = backend
    }

    var isSignedIn: Bool { session != nil }

    func restore() async {
        session = await backend.currentSession()
        isRestoring = false
    }

    func requireSignIn(then action: @escaping () -> Void) {
        if session != nil {
            action()
        } else {
            pendingAction = action
            isPresentingSignIn = true
        }
    }

    func didSignIn(_ session: AuthSession) {
        self.session = session
        isPresentingSignIn = false
        let action = pendingAction
        pendingAction = nil
        // Let the sign-in sheet finish dismissing before presenting what comes next.
        Task {
            try? await Task.sleep(for: .milliseconds(450))
            action?()
        }
    }

    func cancelSignIn() {
        pendingAction = nil
        isPresentingSignIn = false
    }

    func signOut() async {
        try? await backend.signOut()
        session = nil
    }

    func didDeleteAccount() {
        session = nil
    }
}

enum AppTab: Hashable {
    case map
    case followUp
    case help
    case settings
}

/// Cross-screen navigation: tabs, deep links, the report flow and the zone sheet.
@MainActor
@Observable
final class AppRouter {
    var tab: AppTab = .map
    var isReporting = false
    var pendingZone: ZoneID?
    var isShowingWalkHome = false

    func handle(_ url: URL) {
        guard let link = DeepLink(url: url) else { return }
        switch link {
        case .zone(let id):
            tab = .map
            pendingZone = id
        case .help:
            tab = .help
        case .report:
            tab = .map
            isReporting = true
        }
    }
}
