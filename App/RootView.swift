import SwiftUI

/// Onboarding once, then four tabs. Reporting and sign-in are sheets over everything.
struct RootView: View {
    @Environment(AppEnvironment.self) private var environment
    @AppStorage("brusk.onboarding.done") private var onboardingDone = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        @Bindable var router = environment.router
        @Bindable var session = environment.session

        Group {
            if onboardingDone {
                TabView(selection: $router.tab) {
                    Tab("map.tab", systemImage: "map", value: AppTab.map) {
                        MapScreen(environment: environment)
                    }
                    Tab("followup.title", systemImage: "list.bullet.clipboard", value: AppTab.followUp) {
                        FollowUpScreen(environment: environment)
                    }
                    Tab("help.tab", systemImage: "cross.case", value: AppTab.help) {
                        NavigationStack { HelpScreen() }
                    }
                    Tab("settings.title", systemImage: "gearshape", value: AppTab.settings) {
                        NavigationStack { SettingsView() }
                    }
                }
                .sheet(isPresented: $router.isReporting) {
                    ReportFlowView()
                }
                .sheet(isPresented: $session.isPresentingSignIn, onDismiss: {
                    if !environment.session.isSignedIn { environment.session.cancelSignIn() }
                }) {
                    SignInView()
                }
            } else {
                OnboardingView {
                    withMotion(Motion.standard, reduceMotion: reduceMotion) { onboardingDone = true }
                }
                .transition(.opacity)
            }
        }
        .task { await environment.session.restore() }
        .onOpenURL { environment.router.handle($0) }
    }
}

#Preview("Root") {
    let environment = AppEnvironment.preview()
    RootView()
        .environment(environment)
        .environment(environment.language)
}
