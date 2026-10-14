import BruskCore
import SwiftUI

/// "Guide pour porter plainte" (spec §5 écran 4). Every statement here needs a legal
/// review before publication (HUMAN-WORK.md).
struct ComplaintGuideView: View {
    @Environment(AppEnvironment.self) private var environment

    private let steps: [(symbol: String, title: LocalizedStringKey, body: LocalizedStringKey)] = [
        ("cross.case", "complaint.step.safety.title", "complaint.step.safety.body"),
        ("building.columns", "complaint.step.where.title", "complaint.step.where.body"),
        ("doc.on.clipboard", "complaint.step.bring.title", "complaint.step.bring.body"),
        ("person.2.wave.2", "complaint.step.support.title", "complaint.step.support.body"),
        ("checkmark.shield", "complaint.step.rights.title", "complaint.step.rights.body"),
    ]

    private var seriousReports: [MyReport] {
        environment.store.reports().filter { $0.category.isSerious }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Text("complaint.guide.intro")
                    .textStyle(.body)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: Space.m) {
                    ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                        HStack(alignment: .top, spacing: Space.s + Space.xs) {
                            Text(index + 1, format: .number)
                                .textStyle(.headline)
                                .foregroundStyle(Color.ds(.onAccent))
                                .frame(width: 32, height: 32)
                                .background(Color.ds(.accent), in: Circle())
                                .accessibilityHidden(true)
                            VStack(alignment: .leading, spacing: Space.xs) {
                                Label { Text(step.title) } icon: { Image(systemName: step.symbol) }
                                    .textStyle(.headline)
                                    .foregroundStyle(Color.ds(.textPrimary))
                                Text(step.body)
                                    .textStyle(.subheadline)
                                    .foregroundStyle(Color.ds(.textSecondary))
                            }
                            .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
                .padding(Space.m)
                .cardSurface()

                VStack(alignment: .leading, spacing: Space.s) {
                    SectionHeader("complaint.recap.section")
                    Text("complaint.recap.section.message")
                        .textStyle(.subheadline)
                        .foregroundStyle(Color.ds(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                    if seriousReports.isEmpty {
                        Text("complaint.recap.none")
                            .textStyle(.footnote)
                            .foregroundStyle(Color.ds(.textTertiary))
                    } else {
                        ForEach(seriousReports) { report in
                            NavigationLink {
                                ComplaintRecapView(report: report)
                            } label: {
                                MyReportCard(report: report)
                            }
                            .buttonStyle(PressableButtonStyle())
                        }
                    }
                }

                #if DEBUG
                VerificationBadge()
                #endif
            }
            .padding(Space.gutter)
        }
        .background(Color.ds(.background))
        .navigationTitle(Text("complaint.guide.title"))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// A summary to show a police officer: place, date, time, type, photo. The photo is the
/// unblurred original, which exists only on this phone (spec §5 écran 4).
struct ComplaintRecapView: View {
    let report: MyReport
    @Environment(AppEnvironment.self) private var environment
    @State private var originalPhoto: UIImage?
    @State private var streetName: String?
    @Environment(LanguageStore.self) private var language

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                Label("complaint.recap.localOnly", systemImage: "lock.iphone")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)

                VStack(alignment: .leading, spacing: 0) {
                    recapRow(Text("complaint.recap.type")) { Text(LocalizedStringKey(report.category.titleKey)) }
                    Divider()
                    recapRow(Text("complaint.recap.date")) { Text(report.occurredAt, format: .dateTime.weekday(.wide).day().month(.wide).year()) }
                    Divider()
                    recapRow(Text("complaint.recap.time")) { Text(report.occurredAt, format: .dateTime.hour().minute()) }
                    Divider()
                    recapRow(Text("complaint.recap.place")) {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            if let streetName { Text(verbatim: streetName) }
                            Text(verbatim: String(format: "%.5f, %.5f", report.coordinate.latitude, report.coordinate.longitude))
                                .monospacedDigit()
                                .foregroundStyle(Color.ds(.textSecondary))
                        }
                    }
                    Divider()
                    recapRow(Text("complaint.recap.reference")) {
                        Text(verbatim: String(report.id.uuidString.prefix(8)))
                            .monospaced()
                    }
                }
                .padding(.horizontal, Space.m)
                .cardSurface()

                if let originalPhoto {
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text("complaint.recap.photo")
                            .textStyle(.headline)
                            .foregroundStyle(Color.ds(.textPrimary))
                        Image(uiImage: originalPhoto)
                            .resizable()
                            .scaledToFit()
                            .clipShape(Radius.shape(Radius.medium))
                            .accessibilityLabel(Text("complaint.recap.photo.a11y"))
                        Text("complaint.recap.photo.note")
                            .textStyle(.footnote)
                            .foregroundStyle(Color.ds(.textSecondary))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .padding(Space.gutter)
        }
        .background(Color.ds(.background))
        .navigationTitle(Text("complaint.recap.title"))
        .navigationBarTitleDisplayMode(.inline)
        .task {
            if let file = environment.store.stored(report.id)?.originalPhotoFile,
               let data = OriginalPhotoStore.load(file) {
                originalPhoto = UIImage(data: data)
            }
            let coordinate = report.coordinate
            let locale = language.locale
            streetName = await StreetNamer.streetName(near: coordinate, locale: locale)
        }
    }

    private func recapRow<Value: View>(_ label: Text, @ViewBuilder value: () -> Value) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .firstTextBaseline, spacing: Space.m) {
                label.textStyle(.subheadline).foregroundStyle(Color.ds(.textSecondary)).frame(minWidth: 96, alignment: .leading)
                value().textStyle(.headline).foregroundStyle(Color.ds(.textPrimary))
                Spacer(minLength: 0)
            }
            VStack(alignment: .leading, spacing: Space.xs) {
                label.textStyle(.subheadline).foregroundStyle(Color.ds(.textSecondary))
                value().textStyle(.headline).foregroundStyle(Color.ds(.textPrimary))
            }
        }
        .padding(.vertical, Space.s + Space.xs)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Complaint guide") {
    let environment = AppEnvironment.preview()
    NavigationStack { ComplaintGuideView() }
        .environment(environment)
        .environment(environment.language)
}

#Preview("Complaint recap — dark, French, AX5") {
    let environment = AppEnvironment.preview()
    NavigationStack { ComplaintRecapView(report: DemoData.myReports(now: Date())[2]) }
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}
