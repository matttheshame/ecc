import BruskCore
import SwiftUI

/// SF Symbol in a tinted circle. Scales with Dynamic Type.
struct IconBadge: View {
    enum Size {
        case small, regular, large

        var diameter: CGFloat {
            switch self {
            case .small: 32
            case .regular: 40
            case .large: 56
            }
        }

        var font: Font {
            switch self {
            case .small: .footnote.weight(.semibold)
            case .regular: .body.weight(.semibold)
            case .large: .title2.weight(.semibold)
            }
        }
    }

    let systemName: String
    let color: Color
    var size: Size = .regular
    @ScaledMetric(relativeTo: .body) private var scale: CGFloat = 1

    var body: some View {
        Image(systemName: systemName)
            .font(size.font)
            .foregroundStyle(color)
            .frame(width: size.diameter * min(scale, 1.6), height: size.diameter * min(scale, 1.6))
            .background(color.opacity(0.14), in: Circle())
            .accessibilityHidden(true)
    }
}

extension IconBadge {
    init(category: ReportCategory, size: Size = .regular) {
        self.init(systemName: category.symbolName, color: category.color, size: size)
    }
}

/// Report status as an icon + label capsule. Colour is never the only signal.
struct StatusBadge: View {
    let status: ReportStatus

    var body: some View {
        HStack(spacing: Space.xs) {
            Image(systemName: status.symbolName).accessibilityHidden(true)
            Text(LocalizedStringKey(status.titleKey))
                .fixedSize(horizontal: false, vertical: true)
        }
        .textStyle(.caption)
        .foregroundStyle(status.color)
        .padding(.horizontal, Space.s)
        .padding(.vertical, Space.xs)
        .background(status.color.opacity(PaletteToken.tintAlpha), in: Capsule())
        .background(Color.ds(.surface), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}

/// Marks fictional data so demo zones are never mistaken for real streets.
struct DemoDataPill: View {
    var body: some View {
        Label("common.demoData", systemImage: "theatermasks")
            .textStyle(.caption)
            .foregroundStyle(Color.ds(.textSecondary))
            .padding(.horizontal, Space.s + Space.xs)
            .padding(.vertical, Space.s)
            .glassSurface(in: Capsule())
    }
}

/// Debug-only badge on emergency numbers that still need checking (spec annex B).
struct VerificationBadge: View {
    var body: some View {
        Label("common.toVerify", systemImage: "exclamationmark.circle")
            .textStyle(.caption)
            .foregroundStyle(Color.ds(.categoryRoad))
            .padding(.horizontal, Space.s)
            .padding(.vertical, Space.xs)
            .background(Color.ds(.categoryRoad).opacity(PaletteToken.tintAlpha), in: Capsule())
    }
}

#Preview("Badges") {
    PreviewMatrix {
        VStack(alignment: .leading, spacing: Space.s) {
            HStack(spacing: Space.s) {
                ForEach(ReportCategory.allCases) { IconBadge(category: $0) }
                IconBadge(category: .road, size: .large)
                IconBadge(category: .harassment, size: .small)
            }
            ForEach(ReportStatus.allCases, id: \.self) { StatusBadge(status: $0) }
            DemoDataPill()
            VerificationBadge()
        }
    }
}

#Preview("Badges — dark, AX5") {
    PreviewMatrix {
        VStack(alignment: .leading, spacing: Space.s) {
            ForEach(ReportStatus.allCases, id: \.self) { StatusBadge(status: $0) }
            DemoDataPill()
        }
    }
    .previewAccessibilitySize()
    .preferredColorScheme(.dark)
}
