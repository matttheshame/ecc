import BruskCore
import SwiftUI

// MARK: - Section header

struct SectionHeader<Trailing: View>: View {
    let titleKey: LocalizedStringKey
    @ViewBuilder var trailing: () -> Trailing

    init(_ titleKey: LocalizedStringKey, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.titleKey = titleKey
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: Space.s) {
            Text(titleKey)
                .textStyle(.title)
                .foregroundStyle(Color.ds(.textPrimary))
                .accessibilityAddTraits(.isHeader)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Space.s)
            trailing()
        }
    }
}

extension SectionHeader where Trailing == EmptyView {
    init(_ titleKey: LocalizedStringKey) {
        self.init(titleKey) { EmptyView() }
    }
}

// MARK: - List row

/// Icon, title, optional subtitle, trailing accessory. At least 56 pt tall.
/// Title and subtitle are `Text` so callers can pass formatted dates and plurals.
struct ListRow<Trailing: View>: View {
    var systemImage: String?
    var tint: Color = .ds(.accent)
    let title: Text
    var subtitle: Text?
    @ViewBuilder var trailing: () -> Trailing

    init(systemImage: String? = nil, tint: Color = .ds(.accent), title: Text, subtitle: Text? = nil, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.systemImage = systemImage
        self.tint = tint
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
    }

    var body: some View {
        HStack(spacing: Space.s + Space.xs) {
            if let systemImage {
                IconBadge(systemName: systemImage, color: tint, size: .regular)
            }
            VStack(alignment: .leading, spacing: 2) {
                title
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                if let subtitle {
                    subtitle
                        .textStyle(.subheadline)
                        .foregroundStyle(Color.ds(.textSecondary))
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: Space.s)
            trailing()
        }
        .frame(minHeight: ControlSize.row)
        .contentShape(Rectangle())
    }
}

extension ListRow where Trailing == EmptyView {
    init(systemImage: String? = nil, tint: Color = .ds(.accent), title: Text, subtitle: Text? = nil) {
        self.init(systemImage: systemImage, tint: tint, title: title, subtitle: subtitle) { EmptyView() }
    }
}

// MARK: - Metric

/// A number with a caption, e.g. "12 · confirmed reports".
struct MetricTile: View {
    let value: Int
    let labelKey: LocalizedStringKey
    var color: Color = .ds(.textPrimary)

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text(value, format: .number)
                .textStyle(.metricSmall)
                .foregroundStyle(color)
                .contentTransition(.numericText())
            Text(labelKey)
                .textStyle(.footnote)
                .foregroundStyle(Color.ds(.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.m)
        .cardSurface(radius: Radius.medium)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Status timeline

/// Vertical progress through the four statuses (spec §5 écran 3), with the current
/// step's explanation. Reached steps are filled; colour is backed by icons and text.
struct StatusTimeline: View {
    let status: ReportStatus

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(ReportStatus.allCases, id: \.self) { step in
                let reached = step <= status
                HStack(alignment: .top, spacing: Space.s + Space.xs) {
                    VStack(spacing: 0) {
                        Image(systemName: reached ? "\(step.symbolName).fill" : step.symbolName)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(reached ? Color.ds(.onAccent) : Color.ds(.textTertiary))
                            .frame(width: 28, height: 28)
                            .background(reached ? step.color : Color.ds(.surfaceSecondary), in: Circle())
                        if step != .resolved {
                            Rectangle()
                                .fill(step < status ? step.color : Color.ds(.separator))
                                .frame(width: 2)
                                .frame(minHeight: Space.m)
                        }
                    }
                    VStack(alignment: .leading, spacing: Space.xs) {
                        Text(LocalizedStringKey(step.titleKey))
                            .textStyle(step == status ? .headline : .subheadline)
                            .foregroundStyle(reached ? Color.ds(.textPrimary) : Color.ds(.textTertiary))
                        if step == status {
                            Text(LocalizedStringKey(step.explanationKey))
                                .textStyle(.subheadline)
                                .foregroundStyle(Color.ds(.textSecondary))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.bottom, Space.m)
                }
                .accessibilityElement(children: .combine)
                .accessibilityValue(step == status ? Text("common.selected") : Text(verbatim: ""))
            }
        }
    }
}

#Preview("Content") {
    PreviewMatrix {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader("status.confirmed.title") { StatusBadge(status: .confirmed) }
            ListRow(systemImage: ReportCategory.road.symbolName, tint: ReportCategory.road.color,
                    title: Text("category.road.title"), subtitle: Text("category.road.hint")) {
                Image(systemName: "chevron.right").foregroundStyle(Color.ds(.textTertiary))
            }
            HStack(spacing: Space.s) {
                MetricTile(value: 12, labelKey: "status.confirmed.title")
                MetricTile(value: 3, labelKey: "status.resolved.title", color: .ds(.statusResolved))
            }
            StatusTimeline(status: .confirmed)
        }
    }
}

#Preview("Content — dark, AX5") {
    PreviewMatrix {
        VStack(alignment: .leading, spacing: Space.m) {
            ListRow(systemImage: ReportCategory.cleanliness.symbolName, tint: ReportCategory.cleanliness.color,
                    title: Text("category.cleanliness.title"), subtitle: Text("category.cleanliness.hint"))
            StatusTimeline(status: .sent)
        }
    }
    .previewAccessibilitySize()
    .preferredColorScheme(.dark)
}
