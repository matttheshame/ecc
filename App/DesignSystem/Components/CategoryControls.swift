import BruskCore
import SwiftUI

/// Map filter chip. States: selected, unselected, disabled.
struct CategoryChip: View {
    let category: ReportCategory
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            HStack(spacing: Space.s) {
                Image(systemName: category.symbolName)
                    .font(.footnote.weight(.semibold))
                    .accessibilityHidden(true)
                Text(LocalizedStringKey(category.shortTitleKey))
                    .textStyle(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
            }
            .foregroundStyle(isSelected ? category.color : Color.ds(.textSecondary))
            .padding(.horizontal, Space.s + Space.xs)
            .frame(minHeight: ControlSize.chip)
            .background {
                Capsule()
                    .fill(isSelected ? category.color.opacity(PaletteToken.tintAlpha) : .clear)
                    .background(Color.ds(.surface), in: Capsule())
            }
            .overlay(Capsule().strokeBorder(isSelected ? category.color : Color.ds(.separator), lineWidth: isSelected ? 1.5 : 1))
            .contentShape(Capsule())
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(LocalizedStringKey(category.titleKey)))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dsAnimation(Motion.quick, value: isSelected)
    }
}

/// Large choice tile for step 1 of the report flow ("What?"). States: default,
/// selected, pressed, disabled.
struct CategoryTile: View {
    let category: ReportCategory
    let isSelected: Bool
    let action: () -> Void
    @Environment(\.isEnabled) private var isEnabled

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: Space.s) {
                IconBadge(category: category, size: .large)
                Spacer(minLength: Space.s)
                Text(LocalizedStringKey(category.titleKey))
                    .textStyle(.headline)
                    .foregroundStyle(Color.ds(.textPrimary))
                    .fixedSize(horizontal: false, vertical: true)
                Text(LocalizedStringKey(category.hintKey))
                    .textStyle(.footnote)
                    .foregroundStyle(Color.ds(.textSecondary))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            .frame(maxWidth: .infinity, minHeight: 160, alignment: .topLeading)
            .padding(Space.m)
            .background(isSelected ? category.color.opacity(0.08) : .clear, in: Radius.shape(Radius.large))
            .cardSurface()
            .overlay(Radius.shape(Radius.large).strokeBorder(category.color, lineWidth: isSelected ? 2 : 0))
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(category.color)
                        .padding(Space.m)
                        .transition(.scale.combined(with: .opacity))
                        .accessibilityHidden(true)
                }
            }
            .contentShape(Radius.shape(Radius.large))
            .opacity(isEnabled ? 1 : 0.4)
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .dsAnimation(Motion.emphasized, value: isSelected)
    }
}

#Preview("Category chips") {
    PreviewMatrix {
        ScrollView(.horizontal) {
            HStack(spacing: Space.s) {
                CategoryChip(category: .road, isSelected: true) {}
                CategoryChip(category: .cleanliness, isSelected: false) {}
                CategoryChip(category: .insecurity, isSelected: true) {}
                CategoryChip(category: .harassment, isSelected: false) {}.disabled(true)
            }
        }
    }
}

#Preview("Category tiles — light / dark / AX5") {
    PreviewMatrix {
        Grid(horizontalSpacing: Space.s + Space.xs, verticalSpacing: Space.s + Space.xs) {
            GridRow {
                CategoryTile(category: .road, isSelected: true) {}
                CategoryTile(category: .cleanliness, isSelected: false) {}
            }
            GridRow {
                CategoryTile(category: .insecurity, isSelected: false) {}
                CategoryTile(category: .harassment, isSelected: false) {}.disabled(true)
            }
        }
    }
}

#Preview("Category tiles — dark AX5") {
    PreviewMatrix {
        VStack(spacing: Space.s) {
            ForEach(ReportCategory.allCases) { CategoryTile(category: $0, isSelected: $0 == .harassment) {} }
        }
    }
    .previewAccessibilitySize()
    .preferredColorScheme(.dark)
}
