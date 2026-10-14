import BruskBackend
import BruskCore
import Foundation
import Observation

/// App-wide dependencies, created once at launch and injected through the environment.
@MainActor
@Observable
final class AppEnvironment {
    let backend: any Backend
    let language: LanguageStore
    let session: SessionStore
    let router: AppRouter
    let location: LocationService
    let store: LocalStore
    let walk: WalkHomeService

    init(backend: any Backend, language: LanguageStore, store: LocalStore) {
        self.backend = backend
        self.language = language
        self.store = store
        session = SessionStore(backend: backend)
        router = AppRouter()
        location = LocationService()
        walk = WalkHomeService(backend: backend)
    }

    /// Supabase when `SUPABASE_HOST` / `SUPABASE_ANON_KEY` are set (Config/Secrets.xcconfig),
    /// otherwise the labelled demo backend so the app is fully explorable without a server.
    static func live() -> AppEnvironment {
        AppEnvironment(backend: makeBackend(), language: LanguageStore(), store: LocalStore())
    }

    static func preview(signedIn: Bool = true) -> AppEnvironment {
        let environment = AppEnvironment(
            backend: DemoBackend(signedIn: signedIn, latency: .zero),
            language: LanguageStore(defaults: UserDefaults(suiteName: "preview") ?? .standard),
            store: LocalStore(inMemory: true)
        )
        if signedIn {
            environment.session.didSignIn(AuthSession(userID: UUID(), email: "demo@example.org"))
        }
        return environment
    }

    private static func makeBackend() -> any Backend {
        let info = Bundle.main.infoDictionary ?? [:]
        guard let host = (info["SUPABASE_HOST"] as? String)?.trimmingCharacters(in: .whitespaces), !host.isEmpty,
              let key = (info["SUPABASE_ANON_KEY"] as? String)?.trimmingCharacters(in: .whitespaces), !key.isEmpty,
              let url = URL(string: "https://\(host)") else {
            return DemoBackend()
        }
        return SupabaseBackend(url: url, anonKey: key)
    }

    /// Whether unverified emergency numbers may be shown (Debug builds only, with a badge).
    static var showsUnverifiedContacts: Bool {
        #if DEBUG
        true
        #else
        false
        #endif
    }
}
