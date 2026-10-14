import BruskCore
import MapKit
import SwiftUI

/// One of my reports. Only its author sees the exact pin.
struct ReportDetailView: View {
    let report: MyReport
    let onDelete: (MyReport) -> Void
    @Environment(LanguageStore.self) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var streetName: String?
    @State private var isSharing = false
    @State private var isConfirmingDelete = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                header
                map
                if report.status.isOpen { counter }
                StatusTimeline(status: report.status)
                    .padding(Space.m)
                    .cardSurface()
                if let destination = report.routedTo {
                    ListRow(systemImage: "paperplane", tint: .ds(.statusSent), title: Text("followup.detail.routedTo"), subtitle: Text(LocalizedStringKey(destination.titleKey)))
                        .padding(.horizontal, Space.m)
                        .cardSurface(radius: Radius.medium)
                } else if report.category.isSerious {
                    Label("followup.detail.neverAutoSent", systemImage: "lock.shield")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ds(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if report.category.isSerious {
                    NavigationLink {
                        ComplaintRecapView(report: report)
                    } label: {
                        ListRow(systemImage: "doc.text", tint: .ds(.accent), title: Text("complaint.recap.button"), subtitle: Text("complaint.recap.button.subtitle")) {
                            Image(systemName: "chevron.right").foregroundStyle(Color.ds(.textTertiary)).accessibilityHidden(true)
                        }
                        .padding(.horizontal, Space.m)
                        .cardSurface(radius: Radius.medium)
                    }
                    .buttonStyle(PressableButtonStyle())
                }
                DSButton("followup.detail.delete", systemImage: "trash", kind: .tertiary) {
                    isConfirmingDelete = true
                }
            }
            .padding(Space.gutter)
        }
        .background(Color.ds(.background))
        .navigationTitle(Text(LocalizedStringKey(report.category.titleKey)))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            let coordinate = report.coordinate
            let locale = language.locale
            streetName = await StreetNamer.streetName(near: coordinate, locale: locale)
        }
        .sheet(isPresented: $isSharing) { ShareCardSheet(content: shareContent) }
        .confirmationDialog(Text("followup.detail.delete.title"), isPresented: $isConfirmingDelete, titleVisibility: .visible) {
            Button(role: .destructive) {
                onDelete(report)
                dismiss()
            } label: {
                Text("common.delete")
            }
        } message: {
            Text("followup.detail.delete.message")
        }
    }

    private var header: some View {
        HStack(alignment: .top, spacing: Space.m) {
            IconBadge(category: report.category, size: .large)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(report.occurredAt, format: .dateTime.weekday(.wide).day().month(.wide).hour().minute())
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                if let streetName {
                    Text(verbatim: streetName)
                        .textStyle(.subheadline)
                        .foregroundStyle(Color.ds(.textSecondary))
                }
                StatusBadge(status: report.status)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var map: some View {
        Map(initialPosition: .region(MKCoordinateRegion(center: report.coordinate.clCoordinate, latitudinalMeters: 400, longitudinalMeters: 400)), interactionModes: []) {
            Marker(coordinate: report.coordinate.clCoordinate) {
                Text(LocalizedStringKey(report.category.titleKey))
            }
            .tint(report.category.markColor)
        }
        .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll))
        .frame(height: 180)
        .clipShape(Radius.shape(Radius.large))
        .overlay(alignment: .bottomLeading) {
            Label("followup.detail.onlyYou", systemImage: "eye.slash")
                .textStyle(.caption)
                .foregroundStyle(Color.ds(.textPrimary))
                .padding(.horizontal, Space.s + Space.xs)
                .padding(.vertical, Space.s)
                .glassSurface(in: Capsule())
                .padding(Space.s)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("followup.detail.map.a11y"))
    }

    /// Big "still unresolved" counter with the share action (spec §5 écran 3, §7).
    private var counter: some View {
        let days = ProblemAge.days(since: report.createdAt)
        return VStack(alignment: .leading, spacing: Space.s) {
            Text("share.card.days \(days)")
                .textStyle(.metric)
                .foregroundStyle(Color.ds(.textPrimary))
                .contentTransition(.numericText())
            Text("followup.detail.counter.caption")
                .textStyle(.subheadline)
                .foregroundStyle(Color.ds(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            if ShareCardContent.isShareable(report.category) {
                DSButton("share.onX", systemImage: "square.and.arrow.up", kind: .secondary) { isSharing = true }
                    .padding(.top, Space.xs)
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface()
        .accessibilityElement(children: .contain)
    }

    private var shareContent: ShareCardContent {
        ShareCardContent(
            kind: .unresolved(days: ProblemAge.days(since: report.createdAt)),
            category: report.category,
            streetName: streetName,
            communeName: nil,
            // No zone id for a single report: the link invites others to report too.
            link: DeepLink.report.shareURL,
            area: ShareCardContent.coarseArea(around: report.coordinate)
        )
    }
}

#Preview("Report detail") {
    let environment = AppEnvironment.preview()
    NavigationStack {
        ReportDetailView(report: DemoData.myReports(now: Date())[0]) { _ in }
    }
    .environment(environment)
    .environment(environment.language)
}

#Preview("Report detail — serious, dark, Dutch, AX5") {
    let environment = AppEnvironment.preview()
    NavigationStack {
        ReportDetailView(report: DemoData.myReports(now: Date())[2]) { _ in }
    }
    .environment(environment)
    .environment(environment.language)
    .environment(\.locale, Locale(identifier: "nl_BE"))
    .previewAccessibilitySize()
    .preferredColorScheme(.dark)
}
