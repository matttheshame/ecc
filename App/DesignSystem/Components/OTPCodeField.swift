import SwiftUI

/// Six-digit e-mail code entry (spec §4.1). One real text field drives six drawn boxes,
/// so paste and iOS "From Mail" one-time-code autofill work. States: empty, focused,
/// filled, error, disabled.
struct OTPCodeField: View {
    @Binding var code: String
    var length = 6
    var isError = false
    @FocusState private var isFocused: Bool
    @Environment(\.isEnabled) private var isEnabled
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @ScaledMetric(relativeTo: .title) private var boxHeight: CGFloat = 56

    var body: some View {
        ZStack {
            HStack(spacing: Space.s) {
                ForEach(0..<length, id: \.self) { index in
                    box(at: index)
                }
            }
            .allowsHitTesting(false)
            .accessibilityHidden(true)

            TextField("", text: $code)
                .keyboardType(.numberPad)
                .textContentType(.oneTimeCode)
                .focused($isFocused)
                .foregroundStyle(.clear)
                .tint(.clear)
                .frame(maxWidth: .infinity, minHeight: boxHeight)
                .accessibilityLabel(Text("auth.code.label"))
                .accessibilityValue(Text(verbatim: code))
        }
        .onChange(of: code) { _, newValue in
            let digits = String(newValue.filter(\.isNumber).prefix(length))
            if digits != newValue { code = digits }
        }
        .onAppear { isFocused = true }
        .opacity(isEnabled ? 1 : 0.4)
        .sensoryFeedback(Haptic.error.feedback, trigger: isError) { _, newValue in newValue }
        .modifier(ShakeEffect(shakes: isError && !reduceMotion ? 1 : 0))
        .dsAnimation(Motion.emphasized, value: isError)
    }

    private func box(at index: Int) -> some View {
        let characters = Array(code)
        let digit = index < characters.count ? String(characters[index]) : ""
        let isActive = isFocused && index == min(characters.count, length - 1)
        let stroke: Color = isError ? .ds(.danger) : (isActive ? .ds(.accent) : .ds(.separator))

        return Text(verbatim: digit)
            .textStyle(.metricSmall)
            .foregroundStyle(Color.ds(.textPrimary))
            .frame(maxWidth: .infinity, minHeight: boxHeight)
            .background(Color.ds(.surface), in: Radius.shape(Radius.small + Space.xs))
            .overlay(Radius.shape(Radius.small + Space.xs).strokeBorder(stroke, lineWidth: isActive || isError ? 2 : 1))
            .dsAnimation(Motion.quick, value: isActive)
    }
}

/// Horizontal shake for a rejected code. Skipped entirely with Reduce Motion (the red
/// outline and the error message still signal the problem).
private struct ShakeEffect: GeometryEffect {
    var shakes: CGFloat

    var animatableData: CGFloat {
        get { shakes }
        set { shakes = newValue }
    }

    func effectValue(size: CGSize) -> ProjectionTransform {
        ProjectionTransform(CGAffineTransform(translationX: 8 * sin(shakes * .pi * 4), y: 0))
    }
}

#Preview("OTP field") {
    @Previewable @State var empty = ""
    @Previewable @State var partial = "482"
    @Previewable @State var full = "482913"
    PreviewMatrix {
        VStack(spacing: Space.m) {
            OTPCodeField(code: $empty)
            OTPCodeField(code: $partial)
            OTPCodeField(code: $full, isError: true)
            OTPCodeField(code: $full).disabled(true)
        }
    }
}

#Preview("OTP field — dark, AX5") {
    @Previewable @State var partial = "48"
    PreviewMatrix {
        OTPCodeField(code: $partial)
    }
    .previewAccessibilitySize()
    .preferredColorScheme(.dark)
}
