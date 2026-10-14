import BruskBackend
import BruskCore
import SwiftUI

/// Settings: language (instant switch), account, privacy, about.
struct SettingsView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var language
    @State private var trust: TrustInfo?
    @State private var isConfirmingDelete = false
    @State private var isDeleting = false
    @State private var deleteFailed = false
    @State private var languageTick = 0

    var body: some View {
        List {
            languageSection
            accountSection
            privacySection
            aboutSection
        }
        .scrollContentBackground(.hidden)
        .background(Color.ds(.background))
        .navigationTitle(Text("settings.title"))
        .task(id: environment.session.isSignedIn) { await loadTrust() }
        .haptic(.selection, trigger: languageTick)
        .confirmationDialog(Text("settings.delete.title"), isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(role: .destructive) {
                Task { await deleteAccount() }
            } label: {
                Text("settings.delete.confirm")
            }
        } message: {
            Text("settings.delete.message")
        }
    }

    // MARK: Language

    private var languageSection: some View {
        Section {
            ForEach(AppLanguage.allCases) { option in
                Button {
                    languageTick += 1
                    language.select(option)
                    if let code = option.code {
                        Task { try? await environment.backend.setLanguage(code) }
                    }
                } label: {
                    HStack {
                        Text(option.titleKey)
                            .textStyle(.body)
                            .foregroundStyle(Color.ds(.textPrimary))
                        Spacer()
                        if language.selection == option {
                            Image(systemName: "checkmark")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(Color.ds(.accent))
                                .accessibilityHidden(true)
                        }
                    }
                    .frame(minHeight: Space.minTapTarget)
                    .contentShape(Rectangle())
                }
                .accessibilityAddTraits(language.selection == option ? .isSelected : [])
            }
        } header: {
            Text("settings.language.title")
        } footer: {
            Text("settings.language.footer")
        }
        .listRowBackground(Color.ds(.surface))
    }

    // MARK: Account

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if let session = environment.session.session {
                if let email = session.email {
                    LabeledContent {
                        Text(verbatim: email)
                            .foregroundStyle(Color.ds(.textSecondary))
                    } label: {
                        Text("settings.account.email")
                    }
                    .frame(minHeight: Space.minTapTarget)
                }
                if let trust {
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Label {
                            Text(LocalizedStringKey(trust.level.titleKey))
                        } icon: {
                            Image(systemName: "checkmark.seal")
                        }
                        .textStyle(.headline)
                        .foregroundStyle(Color.ds(.textPrimary))
                        Text(LocalizedStringKey(trust.level.explanationKey))
                            .textStyle(.footnote)
                            .foregroundStyle(Color.ds(.textSecondary))
                    }
                    .padding(.vertical, Space.s)
                    .accessibilityElement(children: .combine)
                }
                Button {
                    Task { await environment.session.signOut() }
                } label: {
                    Text("settings.signOut")
                        .frame(minHeight: Space.minTapTarget)
                }
                Button(role: .destructive) {
                    isConfirmingDelete = true
                } label: {
                    HStack {
                        Text("settings.delete.button")
                        if isDeleting { Spacer(); ProgressView() }
                    }
                    .frame(minHeight: Space.minTapTarget)
                }
                .disabled(isDeleting)
                if deleteFailed {
                    Text("error.generic")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ds(.categoryInsecurity))
                }
            } else {
                Button {
                    environment.session.requireSignIn {}
                } label: {
                    Text("auth.signIn.button")
                        .frame(minHeight: Space.minTapTarget)
                }
            }
        } header: {
            Text("settings.account.title")
        } footer: {
            Text("settings.account.footer")
        }
        .listRowBackground(Color.ds(.surface))
    }

    // MARK: Privacy

    private var privacySection: some View {
        Section {
            NavigationLink {
                PrivacyView()
            } label: {
                Label("settings.privacy.what", systemImage: "hand.raised")
                    .frame(minHeight: Space.minTapTarget)
            }
            if let policy = LegalLinks.privacyPolicy {
                Link(destination: policy) {
                    Label("settings.privacy.policy", systemImage: "doc.text")
                        .frame(minHeight: Space.minTapTarget)
                }
            }
            if let terms = LegalLinks.terms {
                Link(destination: terms) {
                    Label("settings.privacy.terms", systemImage: "doc.plaintext")
                        .frame(minHeight: Space.minTapTarget)
                }
            }
        } header: {
            Text("settings.privacy.title")
        }
        .listRowBackground(Color.ds(.surface))
    }

    // MARK: About

    private var aboutSection: some View {
        Section {
            LabeledContent {
                Text(verbatim: Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—")
                    .monospacedDigit()
            } label: {
                Text("settings.about.version")
            }
            .frame(minHeight: Space.minTapTarget)
            if environment.backend.isDemo {
                Label("settings.about.demo", systemImage: "theatermasks")
                    .foregroundStyle(Color.ds(.textSecondary))
                    .frame(minHeight: Space.minTapTarget)
            }
            #if DEBUG
            NavigationLink {
                DesignSystemGallery()
            } label: {
                Label("settings.gallery.title", systemImage: "paintpalette")
                    .frame(minHeight: Space.minTapTarget)
            }
            #endif
        } header: {
            Text("settings.about.title")
        } footer: {
            Text("help.disclaimer")
        }
        .listRowBackground(Color.ds(.surface))
    }

    // MARK: Actions

    private func loadTrust() async {
        guard environment.session.isSignedIn else {
            trust = nil
            return
        }
        trust = try? await environment.backend.myTrust()
    }

    private func deleteAccount() async {
        isDeleting = true
        deleteFailed = false
        defer { isDeleting = false }
        do {
            try await environment.backend.deleteAccount()
            environment.store.deleteEverything()
            environment.session.didDeleteAccount()
        } catch {
            deleteFailed = true
        }
    }
}

/// Published legal documents. Nil until the lawyer-reviewed pages exist (HUMAN-WORK.md);
/// rows are hidden rather than pointing at a placeholder.
enum LegalLinks {
    static let privacyPolicy: URL? = nil
    static let terms: URL? = nil
}

/// What we collect, what we never collect, who sees what, how long (spec §4.1, §8).
/// Draft wording: must be aligned with the lawyer-reviewed privacy policy.
struct PrivacyView: View {
    private let sections: [(symbol: String, title: LocalizedStringKey, body: LocalizedStringKey)] = [
        ("tray.full", "privacy.collect.title", "privacy.collect.body"),
        ("nosign", "privacy.never.title", "privacy.never.body"),
        ("eye", "privacy.who.title", "privacy.who.body"),
        ("clock.arrow.circlepath", "privacy.retention.title", "privacy.retention.body"),
        ("person.badge.key", "privacy.rights.title", "privacy.rights.body"),
    ]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.m) {
                ForEach(Array(sections.enumerated()), id: \.offset) { _, section in
                    VStack(alignment: .leading, spacing: Space.s) {
                        Label { Text(section.title) } icon: { Image(systemName: section.symbol) }
                            .textStyle(.headline)
                            .foregroundStyle(Color.ds(.textPrimary))
                            .accessibilityAddTraits(.isHeader)
                        Text(section.body)
                            .textStyle(.subheadline)
                            .foregroundStyle(Color.ds(.textSecondary))
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(Space.m)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .cardSurface(radius: Radius.medium)
                }
            }
            .padding(Space.gutter)
        }
        .background(Color.ds(.background))
        .navigationTitle(Text("settings.privacy.what"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview("Settings") {
    let environment = AppEnvironment.preview()
    NavigationStack { SettingsView() }
        .environment(environment)
        .environment(environment.language)
}

#Preview("Settings — dark, French, AX5") {
    let environment = AppEnvironment.preview()
    NavigationStack { SettingsView() }
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}

#Preview("Privacy — Dutch") {
    NavigationStack { PrivacyView() }
        .environment(\.locale, Locale(identifier: "nl_BE"))
}
