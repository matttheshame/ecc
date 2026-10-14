import BruskCore
import SwiftUI

/// "Walking home alone" (spec §5 écran 4).
struct WalkHomeView: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var language
    @AppStorage("brusk.walk.contactEmail") private var contactEmail = ""
    @State private var minutes = 20
    @State private var isConfirmingStop = false
    @FocusState private var emailFocused: Bool
    @ScaledMetric(relativeTo: .largeTitle) private var heroSize: CGFloat = 64

    private var walk: WalkHomeService { environment.walk }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                switch walk.state {
                case .idle, .failed, .starting:
                    setup
                case .active(let session):
                    ActiveWalkView(session: session, onStop: { isConfirmingStop = true })
                case .arrived:
                    arrived
                }
            }
            .padding(Space.gutter)
            .dsAnimation(Motion.standard, value: walk.state)
        }
        .scrollDismissesKeyboard(.interactively)
        .background(Color.ds(.background))
        .navigationTitle(Text("walk.title"))
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(Text("walk.stop.title"), isPresented: $isConfirmingStop, titleVisibility: .visible) {
            Button(role: .destructive) {
                Task { await walk.cancel() }
            } label: {
                Text("walk.stop.confirm")
            }
        } message: {
            Text("walk.stop.message")
        }
    }

    // MARK: Setup

    private var setup: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            VStack(alignment: .leading, spacing: Space.m) {
                ExplainerRow(systemImage: "link", textKey: "walk.explain.link")
                ExplainerRow(systemImage: "bell.badge", textKey: "walk.explain.alert")
                ExplainerRow(systemImage: "trash", textKey: "walk.explain.deletion")
            }
            .padding(Space.m)
            .cardSurface(radius: Radius.medium)

            VStack(alignment: .leading, spacing: Space.s) {
                Text("walk.contact.title")
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                TextField(text: $contactEmail, prompt: Text("walk.contact.placeholder")) {
                    Text("walk.contact.title")
                }
                .keyboardType(.emailAddress)
                .textContentType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($emailFocused)
                .textStyle(.body)
                .padding(Space.m)
                .frame(minHeight: Space.minTapTarget)
                .cardSurface(radius: Radius.medium)
                Text("walk.contact.footnote")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: Space.s) {
                Text("walk.duration.title")
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: Space.s) {
                        ForEach(WalkPlan.durationChoices, id: \.self) { choice in
                            DurationChip(minutes: choice, isSelected: minutes == choice) { minutes = choice }
                        }
                    }
                }
                .scrollClipDisabled()
            }

            if case .failed(let error) = walk.state {
                Banner(kind: .warning, titleKey: LocalizedStringKey(error.messageKey))
            }

            DSButton("walk.start", systemImage: "location.fill", isLoading: walk.state == .starting) {
                emailFocused = false
                environment.location.requestPermission()
                Task { await walk.start(contactEmail: contactEmail.trimmingCharacters(in: .whitespaces), minutes: minutes, language: language.resolved) }
            }
            .disabled(!isValidEmail)
        }
    }

    private var isValidEmail: Bool {
        contactEmail.range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil
    }

    private var arrived: some View {
        VStack(alignment: .leading, spacing: Space.l) {
            Image(systemName: "house.circle.fill")
                .font(.system(size: heroSize))
                .foregroundStyle(Color.ds(.statusResolved))
                .accessibilityHidden(true)
            Text("walk.arrived.title")
                .textStyle(.display)
                .foregroundStyle(Color.ds(.textPrimary))
            Text("walk.arrived.message")
                .textStyle(.body)
                .foregroundStyle(Color.ds(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            DSButton("common.done") { walk.reset() }
        }
    }
}

/// The walk in progress: countdown, link to (re)send, "I'm home".
private struct ActiveWalkView: View {
    let session: WalkSession
    let onStop: () -> Void
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var language
    @State private var homeTaps = 0

    var body: some View {
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let phase = session.plan.phase(at: context.date)
            VStack(alignment: .leading, spacing: Space.l) {
                countdown(phase: phase, now: context.date)
                phaseBanner(phase)

                // The one primary action of a walk comes first.
                DSButton("walk.home", systemImage: "house.fill") {
                    homeTaps += 1
                    Task { await environment.walk.confirmArrival() }
                }

                ShareLink(item: session.shareURL, message: Text("walk.share.message")) {
                    Label("walk.share.button", systemImage: "paperplane")
                }
                .buttonStyle(DSButtonStyle(kind: .secondary))

                if session.plan.canExtend {
                    DSButton("walk.extend", systemImage: "plus", kind: .secondary) {
                        Task { await environment.walk.extend(language: language.resolved) }
                    }
                }

                DSButton("walk.stop.button", kind: .tertiary, action: onStop)

                if let sent = environment.walk.lastSentAt {
                    let time = Text(sent, format: .dateTime.hour().minute())
                    Text("walk.lastShared \(time)")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ds(.textSecondary))
                }
            }
        }
        .haptic(.success, trigger: homeTaps)
    }

    private func countdown(phase: WalkPlan.Phase, now: Date) -> some View {
        let total = session.plan.expectedArrival.timeIntervalSince(session.plan.startedAt)
        let remaining = max(0, session.plan.expectedArrival.timeIntervalSince(now))
        let progress = total > 0 ? remaining / total : 0
        let tint: Color = switch phase {
        case .onTrack: .ds(.accent)
        case .dueSoon: .ds(.categoryRoad)
        case .overdue, .contactAlerted: .ds(.danger)
        }
        return ZStack {
            Circle().stroke(Color.ds(.separator), lineWidth: 10)
            Circle()
                .trim(from: 0, to: progress)
                .stroke(tint, style: StrokeStyle(lineWidth: 10, lineCap: .round))
                .rotationEffect(.degrees(-90))
            VStack(spacing: Space.xs) {
                Text(timerInterval: now...max(now, session.plan.expectedArrival), countsDown: true)
                    .textStyle(.metric)
                    .foregroundStyle(Color.ds(.textPrimary))
                let arrival = Text(session.plan.expectedArrival, format: .dateTime.hour().minute())
                Text("walk.arrivalAt \(arrival)")
                    .textStyle(.subheadline)
                    .foregroundStyle(Color.ds(.textSecondary))
            }
            .multilineTextAlignment(.center)
            .padding(Space.l)
        }
        .frame(maxWidth: 260)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private func phaseBanner(_ phase: WalkPlan.Phase) -> some View {
        switch phase {
        case .onTrack:
            Banner(kind: .info, titleKey: "walk.phase.onTrack.title", messageKey: "walk.phase.onTrack.message")
        case .dueSoon:
            Banner(kind: .info, titleKey: "walk.phase.dueSoon.title", messageKey: "walk.phase.dueSoon.message")
        case .overdue:
            Banner(kind: .warning, titleKey: "walk.phase.overdue.title", messageKey: "walk.phase.overdue.message")
        case .contactAlerted:
            Banner(kind: .serious, titleKey: "walk.phase.alerted.title", messageKey: "walk.phase.alerted.message") {
                EmergencyCallButton(contact: EmergencyDirectory.emergency)
            }
        }
    }
}

private struct ExplainerRow: View {
    let systemImage: String
    let textKey: LocalizedStringKey

    var body: some View {
        HStack(alignment: .top, spacing: Space.s + Space.xs) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ds(.accent))
                .frame(width: 24)
                .accessibilityHidden(true)
            Text(textKey)
                .textStyle(.subheadline)
                .foregroundStyle(Color.ds(.textPrimary))
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

private struct DurationChip: View {
    let minutes: Int
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text("walk.minutes \(minutes)")
                .textStyle(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(isSelected ? Color.ds(.onAccent) : Color.ds(.textPrimary))
                .padding(.horizontal, Space.m)
                .frame(minHeight: ControlSize.chip)
                .background(isSelected ? Color.ds(.accent) : Color.ds(.surface), in: Capsule())
                .overlay(Capsule().strokeBorder(isSelected ? Color.clear : Color.ds(.separator), lineWidth: 1))
                .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .haptic(.selection, trigger: isSelected)
    }
}

#Preview("Walk home — setup") {
    let environment = AppEnvironment.preview()
    NavigationStack { WalkHomeView() }
        .environment(environment)
        .environment(environment.language)
}

#Preview("Walk home — setup, dark, Dutch, AX5") {
    let environment = AppEnvironment.preview()
    NavigationStack { WalkHomeView() }
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "nl_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}
