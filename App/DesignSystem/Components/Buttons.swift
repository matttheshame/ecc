import SwiftUI

enum DSButtonKind {
    /// One per screen: the main commit action.
    case primary
    /// Alternatives next to a primary action.
    case secondary
    /// Low-emphasis text actions.
    case tertiary
    /// Calls and irreversible actions.
    case destructive

    var foreground: Color {
        switch self {
        case .primary: .ds(.onAccent)
        case .secondary, .tertiary: .ds(.accent)
        case .destructive: .ds(.onDanger)
        }
    }

    var background: Color {
        switch self {
        case .primary: .ds(.accent)
        case .secondary: .ds(.accent).opacity(0.14)
        case .tertiary: .clear
        case .destructive: .ds(.danger)
        }
    }
}

/// Visual states: default, pressed (scale + dim), disabled (40 % opacity, exempt from
/// contrast rules per WCAG), loading (spinner keeps the button's size).
struct DSButtonStyle: ButtonStyle {
    let kind: DSButtonKind
    var fullWidth = true
    @Environment(\.isEnabled) private var isEnabled

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .textStyle(.bodyEmphasized)
            .multilineTextAlignment(.center)
            .foregroundStyle(kind.foreground)
            .padding(.horizontal, Space.l)
            .padding(.vertical, Space.s)
            .frame(maxWidth: fullWidth ? .infinity : nil, minHeight: ControlSize.button)
            .background(kind.background, in: Radius.shape(Radius.medium))
            .contentShape(Radius.shape(Radius.medium))
            .opacity(isEnabled ? (configuration.isPressed ? 0.85 : 1) : 0.4)
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .dsAnimation(Motion.quick, value: configuration.isPressed)
    }
}

/// Press feedback only, for custom-drawn buttons (tiles, rows, chips).
struct PressableButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.97 : 1)
            .opacity(configuration.isPressed ? 0.9 : 1)
            .dsAnimation(Motion.quick, value: configuration.isPressed)
    }
}

struct DSButton: View {
    let titleKey: LocalizedStringKey
    var systemImage: String?
    var kind: DSButtonKind = .primary
    var isLoading = false
    var fullWidth = true
    let action: () -> Void

    init(
        _ titleKey: LocalizedStringKey,
        systemImage: String? = nil,
        kind: DSButtonKind = .primary,
        isLoading: Bool = false,
        fullWidth: Bool = true,
        action: @escaping () -> Void
    ) {
        self.titleKey = titleKey
        self.systemImage = systemImage
        self.kind = kind
        self.isLoading = isLoading
        self.fullWidth = fullWidth
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                HStack(spacing: Space.s) {
                    if let systemImage {
                        Image(systemName: systemImage).accessibilityHidden(true)
                    }
                    Text(titleKey).fixedSize(horizontal: false, vertical: true)
                }
                .opacity(isLoading ? 0 : 1)
                if isLoading {
                    ProgressView().tint(kind.foreground)
                }
            }
        }
        .buttonStyle(DSButtonStyle(kind: kind, fullWidth: fullWidth))
        .allowsHitTesting(!isLoading)
        .accessibilityValue(isLoading ? Text("common.loading") : Text(verbatim: ""))
    }
}

/// The map's thumb-reachable "Report" action (spec §5 écran 1).
struct FloatingReportButton: View {
    let action: () -> Void
    @State private var taps = 0

    var body: some View {
        Button {
            taps += 1
            action()
        } label: {
            HStack(spacing: Space.s) {
                Image(systemName: "plus")
                    .font(.title3.weight(.bold))
                    .accessibilityHidden(true)
                Text("map.report.button")
                    .textStyle(.headline)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .foregroundStyle(Color.ds(.onAccent))
            .padding(.horizontal, Space.xl)
            .padding(.vertical, Space.s)
            .frame(minHeight: ControlSize.floatingAction)
            .background(Color.ds(.accent), in: Capsule())
            .contentShape(Capsule())
        }
        .buttonStyle(PressableButtonStyle())
        .elevation(.floating)
        .haptic(.commit, trigger: taps)
        .accessibilityHint(Text("map.report.hint"))
    }
}

#Preview("Buttons — states") {
    PreviewMatrix {
        VStack(spacing: Space.s) {
            DSButton("common.send", systemImage: "paperplane") {}
            DSButton("common.send", isLoading: true) {}
            DSButton("common.send") {}.disabled(true)
            DSButton("common.retry", kind: .secondary) {}
            DSButton("common.skip", kind: .tertiary) {}
            DSButton("help.112.title", systemImage: "phone.fill", kind: .destructive) {}
            FloatingReportButton {}
        }
    }
}

#Preview("Buttons — dark, AX5") {
    PreviewMatrix {
        VStack(spacing: Space.s) {
            DSButton("common.send", systemImage: "paperplane") {}
            DSButton("common.retry", kind: .secondary) {}
            FloatingReportButton {}
        }
    }
    .previewAccessibilitySize()
    .preferredColorScheme(.dark)
}
