import BruskBackend
import BruskCore
import Charts
import SwiftUI

/// Zone sheet (spec §5 écran 1: "type de faits, tendance, score du quartier, nombre de
/// signalements confirmés, ancienneté des problèmes non résolus, bouton de partage").
struct ZoneSheet: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var language
    @Environment(\.dismiss) private var dismiss
    @State private var selection: ZoneSelection
    @State private var detail: ZoneDetail?
    @State private var streetName: String?
    @State private var loadError: BackendError?
    @State private var isSharing = false
    @State private var isFlagging = false
    @State private var flagSent = false
    @State private var selectedWeek: Int?

    init(selection: ZoneSelection) {
        _selection = State(initialValue: selection)
    }

    private var zone: Zone { selection.current }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    header
                    if selection.zones.count > 1 { categorySwitcher }
                    metrics
                    if let detail {
                        weeklyChart(detail)
                        scoreCard(detail)
                    } else if let loadError {
                        StateView(kind: .error(messageKey: LocalizedStringKey(loadError.messageKey)), actionKey: "common.retry") {
                            Task { await load() }
                        }
                    } else {
                        StateView(kind: .loading)
                    }
                    actions
                    Label("zone.privacy.note", systemImage: "eye.slash")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ds(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.gutter)
            }
            .background(Color.ds(.background))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.close") }
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: zone.id) { await load() }
        .sheet(isPresented: $isSharing) {
            ShareCardSheet(content: shareContent)
        }
        .confirmationDialog(Text("zone.flag.title"), isPresented: $isFlagging, titleVisibility: .visible) {
            ForEach(FlagReason.allCases, id: \.self) { reason in
                Button { flag(reason) } label: { Text(LocalizedStringKey(reason.titleKey)) }
            }
        } message: {
            Text("zone.flag.message")
        }
        .haptic(.success, trigger: flagSent)
    }

    // MARK: Sections

    private var header: some View {
        HStack(alignment: .top, spacing: Space.m) {
            IconBadge(category: zone.category, size: .large)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text(LocalizedStringKey(zone.category.titleKey))
                    .textStyle(.title)
                    .foregroundStyle(Color.ds(.textPrimary))
                    .accessibilityAddTraits(.isHeader)
                placeLine
                    .textStyle(.subheadline)
                    .foregroundStyle(Color.ds(.textSecondary))
                Label {
                    Text(LocalizedStringKey(zone.trend.titleKey))
                } icon: {
                    Image(systemName: zone.trend.symbolName)
                }
                .textStyle(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(Color.ds(.textPrimary))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var placeLine: some View {
        let commune = Commune.with(code: zone.communeCode)?.name(in: language.resolved)
        switch (streetName, commune) {
        case let (street?, commune?): Text("zone.near \(street) \(commune)")
        case let (street?, nil): Text("zone.nearStreet \(street)")
        case let (nil, commune?): Text(verbatim: commune)
        case (nil, nil): EmptyView()
        }
    }

    private var categorySwitcher: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: Space.s) {
                ForEach(selection.zones) { candidate in
                    CategoryChip(category: candidate.category, isSelected: candidate.id == zone.id) {
                        selection.current = candidate
                        detail = nil
                    }
                }
            }
        }
    }

    private var metrics: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: Space.s) { metricTiles }
            VStack(spacing: Space.s) { metricTiles }
        }
    }

    @ViewBuilder
    private var metricTiles: some View {
        MetricTile(value: zone.confirmedCount, labelKey: "zone.metric.confirmed")
        if let since = zone.unresolvedSince {
            MetricTile(value: ProblemAge.days(since: since), labelKey: "zone.metric.unresolvedDays", color: .ds(.categoryRoad))
        }
        MetricTile(value: zone.resolvedCount, labelKey: "zone.metric.resolved", color: .ds(.statusResolved))
    }

    /// Single series, so no legend: the title names it. Bars are the category's mark
    /// colour; text stays in text tokens. Tap a bar to read its value.
    private func weeklyChart(_ detail: ZoneDetail) -> some View {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(alignment: .firstTextBaseline) {
                Text("zone.chart.title")
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                Spacer()
                if let selectedWeek, detail.weeklyCounts.indices.contains(selectedWeek) {
                    Text("zone.chart.value \(detail.weeklyCounts[selectedWeek])")
                        .textStyle(.subheadline)
                        .monospacedDigit()
                        .foregroundStyle(Color.ds(.textSecondary))
                }
            }
            Chart(Array(detail.weeklyCounts.enumerated()), id: \.offset) { item in
                BarMark(
                    x: .value("zone.chart.axis.week", item.offset),
                    y: .value("zone.chart.axis.reports", item.element),
                    width: .ratio(0.7)
                )
                .foregroundStyle(zone.category.markColor.opacity(selectedWeek == nil || selectedWeek == item.offset ? 1 : 0.35))
                .cornerRadius(4)
                .accessibilityLabel(weekLabel(item.offset, of: detail.weeklyCounts.count))
                .accessibilityValue(Text("zone.chart.value \(item.element)"))
            }
            .chartXSelection(value: $selectedWeek)
            .chartXAxis {
                AxisMarks(values: [0, detail.weeklyCounts.count - 1]) { value in
                    AxisValueLabel {
                        if let index = value.as(Int.self) { weekLabel(index, of: detail.weeklyCounts.count) }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) {
                    AxisGridLine().foregroundStyle(Color.ds(.separator))
                    AxisValueLabel()
                }
            }
            .frame(height: 140)
        }
        .padding(Space.m)
        .cardSurface(radius: Radius.medium)
    }

    private func weekLabel(_ index: Int, of total: Int) -> Text {
        index == total - 1 ? Text("zone.chart.thisWeek") : Text("zone.chart.weeksAgo \(total - 1 - index)")
    }

    private func scoreCard(_ detail: ZoneDetail) -> some View {
        HStack(spacing: Space.m) {
            Gauge(value: Double(detail.neighbourhoodScore), in: 0...100) {
                EmptyView()
            } currentValueLabel: {
                Text(detail.neighbourhoodScore, format: .number)
                    .textStyle(.metricSmall)
                    .foregroundStyle(Color.ds(.textPrimary))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(Color.ds(.statusResolved))
            .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("zone.score.title")
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                Text("zone.score.explanation")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textSecondary))
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .cardSurface(radius: Radius.medium)
        .accessibilityElement(children: .combine)
        .accessibilityValue(Text("zone.score.value \(detail.neighbourhoodScore)"))
    }

    private var actions: some View {
        VStack(spacing: Space.s) {
            if ShareCardContent.isShareable(zone.category) {
                DSButton("share.onX", systemImage: "square.and.arrow.up") { isSharing = true }
            }
            DSButton("zone.flag.button", systemImage: "flag", kind: .tertiary) {
                environment.session.requireSignIn { isFlagging = true }
            }
            if flagSent {
                Label("zone.flag.thanks", systemImage: "checkmark.circle")
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.statusResolved))
            }
        }
    }

    // MARK: Logic

    private var shareContent: ShareCardContent {
        let commune = Commune.with(code: zone.communeCode)?.name(in: language.resolved)
        let kind: ShareCardContent.Kind
        if let since = zone.unresolvedSince {
            kind = .unresolved(days: ProblemAge.days(since: since))
        } else if zone.resolvedCount > 0 {
            kind = .resolved(count: zone.resolvedCount)
        } else {
            kind = .score(detail?.neighbourhoodScore ?? 0)
        }
        return ShareCardContent(
            kind: kind, category: zone.category, streetName: streetName, communeName: commune,
            link: DeepLink.zone(zone.id).shareURL, area: zone.outline
        )
    }

    private func load() async {
        loadError = nil
        let center = zone.center
        let locale = language.locale
        async let name = StreetNamer.streetName(near: center, locale: locale)
        do {
            detail = try await environment.backend.zoneDetail(zone.id)
        } catch let error as BackendError {
            loadError = error
        } catch {
            loadError = .server(String(describing: error))
        }
        streetName = await name
    }

    private func flag(_ reason: FlagReason) {
        Task {
            try? await environment.backend.flagZone(zone.id, reason: reason)
            flagSent = true
        }
    }
}

#Preview("Zone sheet") {
    let environment = AppEnvironment.preview()
    let zone = DemoData.zones(now: Date())[0]
    ZoneSheet(selection: ZoneSelection(zones: [zone], current: zone))
        .environment(environment)
        .environment(environment.language)
}

#Preview("Zone sheet — dark, French, AX5") {
    let environment = AppEnvironment.preview()
    let zones = DemoData.zones(now: Date())
    ZoneSheet(selection: ZoneSelection(zones: [zones[4], zones[8]], current: zones[4]))
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "fr_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}
