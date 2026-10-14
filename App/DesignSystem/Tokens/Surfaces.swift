import BruskCore
import SwiftUI

// MARK: - Elevation

/// Shadows are soft and only used in light mode; dark mode relies on surface steps and
/// a hairline, which reads better on OLED and avoids muddy halos.
enum Elevation {
    case flat
    case raised
    case floating
}

private struct ElevationModifier: ViewModifier {
    let level: Elevation
    @Environment(\.colorScheme) private var scheme

    @ViewBuilder
    func body(content: Content) -> some View {
        switch level {
        case .flat:
            content
        case .raised:
            content.shadow(color: .black.opacity(scheme == .dark ? 0 : 0.06), radius: 12, x: 0, y: 4)
        case .floating:
            content.shadow(color: .black.opacity(scheme == .dark ? 0.32 : 0.12), radius: 24, x: 0, y: 8)
        }
    }
}

extension View {
    func elevation(_ level: Elevation) -> some View { modifier(ElevationModifier(level: level)) }
}

// MARK: - Glass

/// Liquid Glass on iOS 26, `.ultraThinMaterial` with a hairline on iOS 18–25.
/// Used for chrome floating over the map (filter bar, map buttons), never for content.
private struct GlassSurface<S: Shape>: ViewModifier {
    let shape: S
    let interactive: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        #if compiler(>=6.2)
        if #available(iOS 26.0, *) {
            content.glassEffect(interactive ? .regular.interactive() : .regular, in: shape)
        } else {
            fallback(content)
        }
        #else
        fallback(content)
        #endif
    }

    private func fallback(_ content: Content) -> some View {
        content
            .background(.ultraThinMaterial, in: shape)
            .overlay(shape.stroke(Color.ds(.separator).opacity(0.7), lineWidth: 0.5))
    }
}

extension View {
    func glassSurface<S: Shape>(in shape: S, interactive: Bool = false) -> some View {
        modifier(GlassSurface(shape: shape, interactive: interactive))
    }

    /// Opaque content card: surface fill, continuous corners, hairline.
    func cardSurface(radius: CGFloat = Radius.large) -> some View {
        background(Color.ds(.surface), in: Radius.shape(radius))
            .overlay(Radius.shape(radius).strokeBorder(Color.ds(.separator).opacity(0.6), lineWidth: 0.5))
    }
}
