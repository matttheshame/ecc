import BruskCore
import SwiftUI

/// Screen 4 (spec §5): emergency help. 112 first, always one gesture away.
struct HelpScreen: View {
    /// True when shown as a sheet from the report flow (adds a Close button).
    var isModal = false
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.dismiss) private var dismiss
    @State private var isShowingWalk = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                VStack(alignment: .leading, spacing: Space.s) {
                    Text("help.title")
                        .textStyle(.display)
                        .foregroundStyle(Color.ds(.textPrimary))
                        .accessibilityAddTraits(.isHeader)
                    Text("help.subtitle")
                        .textStyle(.body)
                        .foregroundStyle(Color.ds(.textSecondary))
                }
                .fixedSize(horizontal: false, vertical: true)

                VStack(spacing: Space.s + Space.xs) {
                    EmergencyCallButton(contact: EmergencyDirectory.emergency)
                    EmergencyCallButton(contact: EmergencyDirectory.police, prominence: .secondary)
                }

                VStack(spacing: Space.s + Space.xs) {
                    Button {
                        environment.session.requireSignIn { isShowingWalk = true }
                    } label: {
                        HelpCard(
                            systemImage: "figure.walk.motion",
                            tint: .ds(.accent),
                            titleKey: environment.walk.activeSession == nil ? "walk.card.title" : "walk.card.active",
                            messageKey: "walk.card.message"
                        )
                    }
                    .buttonStyle(PressableButtonStyle())

                    NavigationLink {
                        ComplaintGuideView()
                    } label: {
                        HelpCard(systemImage: "doc.text.magnifyingglass", tint: .ds(.statusSent), titleKey: "complaint.card.title", messageKey: "complaint.card.message")
                    }
                    .buttonStyle(PressableButtonStyle())
                }

                contacts

                Label("help.disclaimer", systemImage: "info.circle")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(Space.gutter)
        }
        .background(Color.ds(.background))
        .navigationTitle(Text("help.tab"))
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $isShowingWalk) { WalkHomeView() }
        .toolbar {
            if isModal {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.close") }
                }
            }
        }
        .onChange(of: environment.router.isShowingWalkHome) { _, show in
            if show {
                environment.router.isShowingWalkHome = false
                environment.session.requireSignIn { isShowingWalk = true }
            }
        }
    }

    @ViewBuilder
    private var contacts: some View {
        let visible = EmergencyDirectory.visibleSupport(includeUnverified: AppEnvironment.showsUnverifiedContacts)
        if !visible.isEmpty {
            VStack(alignment: .leading, spacing: Space.s + Space.xs) {
                SectionHeader("help.contacts.title")
                ForEach(visible) { contact in
                    VStack(alignment: .leading, spacing: Space.xs) {
                        EmergencyCallButton(contact: contact, prominence: .secondary)
                        if contact.verification == .toVerify {
                            VerificationBadge()
                        }
                    }
                }
            }
        }
    }
}

/// Large tappable card with icon, title and one line of explanation.
struct HelpCard: View {
    let systemImage: String
    let tint: Color
    let titleKey: LocalizedStringKey
    let messageKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: Space.m) {
            IconBadge(systemName: systemImage, color: tint, size: .regular)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(titleKey)
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                Text(messageKey)
                    .textStyle(.subheadline)
                    .foregroundStyle(Color.ds(.textSecondary))
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(Color.ds(.textTertiary))
                .accessibilityHidden(true)
        }
        .padding(Space.m)
        .cardSurface(radius: Radius.medium)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Help") {
    let environment = AppEnvironment.preview()
    NavigationStack { HelpScreen() }
        .environment(environment)
        .environment(environment.language)
}

#Preview("Help — dark, Dutch, AX5") {
    let environment = AppEnvironment.preview()
    NavigationStack { HelpScreen() }
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "nl_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}
