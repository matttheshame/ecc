import SwiftUI

@main
struct BruskApp: App {
    @State private var environment = AppEnvironment.live()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(environment)
                .environment(environment.language)
                // In-app language switch: every Text re-resolves against this locale.
                .environment(\.locale, environment.language.locale)
                .tint(Color.ds(.accent))
                .modelContainer(environment.store.container)
        }
    }
}
