import BruskCore
import SwiftUI

/// One-gesture call (spec §4.4, §8: "appel direct en un geste"). iOS shows its own
/// confirmation before dialling, which prevents pocket calls.
struct EmergencyCallButton: View {
    enum Prominence {
        /// 112: full-width, filled red, largest type.
        case primary
        /// 101 and support lines: outlined.
        case secondary
    }

    let contact: EmergencyContact
    var prominence: Prominence = .primary
    @Environment(\.openURL) private var openURL
    @State private var taps = 0
    /// The big numeral follows Dynamic Type like the rest of the scale.
    @ScaledMetric(relativeTo: .largeTitle) private var numeralSize: CGFloat = 44

    var body: some View {
        Button {
            taps += 1
            if let url = contact.telURL { openURL(url) }
        } label: {
            HStack(spacing: Space.m) {
                if let phone = contact.displayPhone, prominence == .primary {
                    Text(verbatim: phone)
                        .font(.system(size: numeralSize, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .minimumScaleFactor(0.8)
                }
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(LocalizedStringKey(contact.titleKey))
                        .textStyle(.headline)
                    Text(LocalizedStringKey(contact.detailKey))
                        .textStyle(.subheadline)
                        .opacity(prominence == .primary ? 0.9 : 1)
                        .foregroundStyle(prominence == .primary ? Color.ds(.onDanger) : Color.ds(.textSecondary))
                    if prominence == .secondary, let phone = contact.displayPhone {
                        Text(verbatim: phone)
                            .textStyle(.subheadline)
                            .monospacedDigit()
                            .foregroundStyle(Color.ds(.textSecondary))
                    }
                }
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: Space.s)
                Image(systemName: "phone.fill")
                    .font(.title3)
                    .accessibilityHidden(true)
            }
            .foregroundStyle(prominence == .primary ? Color.ds(.onDanger) : Color.ds(.danger))
            .padding(prominence == .primary ? Space.l : Space.m)
            .frame(maxWidth: .infinity, minHeight: prominence == .primary ? 104 : ControlSize.row, alignment: .leading)
            .background(prominence == .primary ? Color.ds(.danger) : Color.ds(.surface), in: Radius.shape(Radius.large))
            .overlay(Radius.shape(Radius.large).strokeBorder(Color.ds(.danger).opacity(prominence == .primary ? 0 : 0.5), lineWidth: 1))
            .contentShape(Radius.shape(Radius.large))
        }
        .buttonStyle(PressableButtonStyle())
        .disabled(contact.telURL == nil)
        .haptic(.commit, trigger: taps)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
    }
}

#Preview("Emergency buttons") {
    PreviewMatrix {
        VStack(spacing: Space.s) {
            EmergencyCallButton(contact: EmergencyDirectory.emergency)
            EmergencyCallButton(contact: EmergencyDirectory.police, prominence: .secondary)
            EmergencyCallButton(contact: EmergencyDirectory.support[2], prominence: .secondary)
            EmergencyCallButton(contact: EmergencyDirectory.support[0], prominence: .secondary)
        }
    }
}

#Preview("Emergency buttons — dark, AX5") {
    PreviewMatrix {
        VStack(spacing: Space.s) {
            EmergencyCallButton(contact: EmergencyDirectory.emergency)
            EmergencyCallButton(contact: EmergencyDirectory.police, prominence: .secondary)
        }
    }
    .previewAccessibilitySize()
    .preferredColorScheme(.dark)
}
