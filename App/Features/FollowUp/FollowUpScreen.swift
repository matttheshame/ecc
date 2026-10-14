import BruskCore
import SwiftUI

/// Screen 3 (spec §5): my reports with their status, reports around me to confirm in
/// one gesture, and the "still unresolved" counter.
struct FollowUpScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: FollowUpViewModel

    init(environment: AppEnvironment) {
        _model = State(initialValue: FollowUpViewModel(environment: environment))
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.xl) {
                    if environment.session.isSignedIn {
                        myReportsSection
                        nearbySection
                    } else {
                        StateView(
                            kind: .empty(symbol: "person.crop.circle.badge.checkmark", titleKey: "followup.signedOut.title", messageKey: "followup.signedOut.message"),
                            actionKey: "auth.signIn.button"
                        ) {
                            environment.session.requireSignIn {}
                        }
                    }
                }
                .padding(Space.gutter)
            }
            .background(Color.ds(.background))
            .navigationTitle(Text("followup.title"))
            .refreshable { await model.load() }
            .navigationDestination(for: MyReport.self) { report in
                ReportDetailView(report: report) { deleted in
                    Task { _ = await model.delete(deleted) }
                }
            }
        }
        .task(id: environment.session.isSignedIn) { await model.load() }
        .onChange(of: environment.router.isReporting) { _, isReporting in
            if !isReporting { Task { await model.load() } }
        }
        .haptic(.success, trigger: model.confirmations)
    }

    // MARK: My reports

    @ViewBuilder
    private var myReportsSection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader("followup.mine.title") {
                if model.isLoadingReports && !model.reports.isEmpty {
                    ProgressView().controlSize(.small)
                }
            }
            if model.reports.isEmpty {
                if model.isLoadingReports {
                    StateView(kind: .loading)
                } else if let error = model.reportsError {
                    StateView(kind: .error(messageKey: LocalizedStringKey(error.messageKey)), actionKey: "common.retry") {
                        Task { await model.load() }
                    }
                } else {
                    StateView(
                        kind: .empty(symbol: "mappin.and.ellipse", titleKey: "followup.mine.empty.title", messageKey: "followup.mine.empty.message"),
                        actionKey: "map.report.button"
                    ) {
                        environment.router.tab = .map
                        environment.router.isReporting = true
                    }
                }
            } else {
                ForEach(model.openReports + model.resolvedReports) { report in
                    NavigationLink(value: report) {
                        MyReportCard(report: report)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
            }
        }
    }

    // MARK: Around me

    @ViewBuilder
    private var nearbySection: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader("followup.nearby.title")
            Text("followup.nearby.explanation")
                .textStyle(.subheadline)
                .foregroundStyle(Color.ds(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)

            if let error = model.confirmError {
                Banner(kind: .warning, titleKey: LocalizedStringKey(error.messageKey))
            }

            switch model.nearbyState {
            case .idle, .loading where model.nearby.isEmpty:
                StateView(kind: .loading)
            case .needsLocation:
                StateView(
                    kind: .empty(symbol: "location.slash", titleKey: "followup.nearby.location.title", messageKey: "followup.nearby.location.message"),
                    actionKey: "followup.nearby.location.button"
                ) {
                    environment.location.requestPermission()
                    Task { await model.loadNearby() }
                }
            case .failed(let error) where model.nearby.isEmpty:
                StateView(kind: .error(messageKey: LocalizedStringKey(error.messageKey)), actionKey: "common.retry") {
                    Task { await model.loadNearby() }
                }
            default:
                if model.nearby.isEmpty {
                    StateView(kind: .empty(symbol: "checkmark.seal", titleKey: "followup.nearby.empty.title", messageKey: "followup.nearby.empty.message"))
                } else {
                    VStack(spacing: Space.s) {
                        ForEach(model.nearby) { report in
                            NearbyRow(
                                report: report,
                                isConfirming: model.confirming.contains(report.id),
                                isConfirmed: model.justConfirmed.contains(report.id)
                            ) {
                                Task { await model.confirm(report) }
                            }
                            .transition(reduceMotion ? .opacity : .move(edge: .trailing).combined(with: .opacity))
                        }
                    }
                    .dsAnimation(Motion.standard, value: model.nearby.map(\.id))
                }
            }
        }
    }
}

// MARK: - Rows

/// One of my reports: category, status and the "still unresolved" counter.
struct MyReportCard: View {
    let report: MyReport

    var body: some View {
        HStack(alignment: .top, spacing: Space.s + Space.xs) {
            IconBadge(category: report.category)
            VStack(alignment: .leading, spacing: Space.s) {
                Text(LocalizedStringKey(report.category.titleKey))
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                StatusBadge(status: report.status)
                AgeLine(report: report)
            }
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

/// "Reported 12 days ago, still unresolved" (spec §5 écran 3, compteur de lenteur).
struct AgeLine: View {
    let report: MyReport

    var body: some View {
        let days = ProblemAge.days(since: report.createdAt)
        Group {
            if report.status.isOpen {
                if days == 0 {
                    Text("followup.age.today")
                } else {
                    let age = Text("common.days \(days)")
                    Text("followup.age.unresolved \(age)")
                }
            } else {
                Text("followup.age.resolved")
            }
        }
        .textStyle(.subheadline)
        .foregroundStyle(Color.ds(.textSecondary))
    }
}

/// A report nearby, confirmable in one tap. Shows the cell, never the exact point.
struct NearbyRow: View {
    let report: NearbyReport
    let isConfirming: Bool
    let isConfirmed: Bool
    let onConfirm: () -> Void

    var body: some View {
        HStack(spacing: Space.s + Space.xs) {
            IconBadge(category: report.category)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(LocalizedStringKey(report.category.titleKey))
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                subtitle
                    .textStyle(.subheadline)
                    .foregroundStyle(Color.ds(.textSecondary))
                if report.confirmations > 0 {
                    Text("followup.nearby.confirmations \(report.confirmations)")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ds(.textTertiary))
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .accessibilityElement(children: .combine)

            confirmButton
        }
        .padding(Space.m)
        .cardSurface(radius: Radius.medium)
    }

    private var subtitle: Text {
        let distance = Text(Measurement(value: Double(report.distanceMeters), unit: UnitLength.meters), format: .measurement(width: .abbreviated, usage: .asProvided))
        let time = Text(report.occurredAt, format: .relative(presentation: .named))
        return Text("followup.nearby.subtitle \(distance) \(time)")
    }

    @ViewBuilder
    private var confirmButton: some View {
        if isConfirmed {
            Image(systemName: "checkmark.circle.fill")
                .font(.title2)
                .foregroundStyle(Color.ds(.statusResolved))
                .frame(minWidth: Space.minTapTarget, minHeight: Space.minTapTarget)
                .transition(.scale.combined(with: .opacity))
                .accessibilityLabel(Text("followup.nearby.confirmed"))
        } else {
            DSButton("followup.nearby.confirm", systemImage: "checkmark", kind: .secondary, isLoading: isConfirming, fullWidth: false, action: onConfirm)
                .accessibilityHint(Text("followup.nearby.confirm.hint"))
        }
    }
}

#Preview("Follow-up") {
    let environment = AppEnvironment.preview()
    FollowUpScreen(environment: environment)
        .environment(environment)
        .environment(environment.language)
}

#Preview("Follow-up — dark, Dutch, AX5") {
    let environment = AppEnvironment.preview()
    FollowUpScreen(environment: environment)
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "nl_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}

#Preview("Follow-up — signed out, French") {
    let environment = AppEnvironment.preview(signedIn: false)
    FollowUpScreen(environment: environment)
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "fr_BE"))
}
