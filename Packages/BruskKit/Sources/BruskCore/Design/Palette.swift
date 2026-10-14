import Foundation

/// An sRGB colour stored as a 24-bit hex value. Platform-neutral so contrast rules
/// can be unit-tested without UIKit.
public struct RGB: Hashable, Sendable, CustomStringConvertible {
    public let red: Double
    public let green: Double
    public let blue: Double

    public init(_ hex: UInt32) {
        red = Double((hex >> 16) & 0xFF) / 255
        green = Double((hex >> 8) & 0xFF) / 255
        blue = Double(hex & 0xFF) / 255
    }

    public init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    public var description: String {
        String(format: "#%02X%02X%02X", Int(red * 255), Int(green * 255), Int(blue * 255))
    }

    /// Relative luminance as defined by WCAG 2.x.
    public var luminance: Double {
        func channel(_ c: Double) -> Double {
            c <= 0.03928 ? c / 12.92 : pow((c + 0.055) / 1.055, 2.4)
        }
        return 0.2126 * channel(red) + 0.7152 * channel(green) + 0.0722 * channel(blue)
    }

    /// Alpha-composites `self` at `alpha` over `background`.
    public func over(_ background: RGB, alpha: Double) -> RGB {
        RGB(
            red: red * alpha + background.red * (1 - alpha),
            green: green * alpha + background.green * (1 - alpha),
            blue: blue * alpha + background.blue * (1 - alpha)
        )
    }
}

public enum WCAG {
    /// Contrast ratio between two colours (1…21).
    public static func contrast(_ a: RGB, _ b: RGB) -> Double {
        let (hi, lo) = a.luminance >= b.luminance ? (a.luminance, b.luminance) : (b.luminance, a.luminance)
        return (hi + 0.05) / (lo + 0.05)
    }

    /// AA for body text.
    public static let textMinimum = 4.5
    /// AA for large text (≥ 18 pt regular / 14 pt bold) and non-text UI (icons, outlines).
    public static let nonTextMinimum = 3.0
}

/// A colour that resolves differently in light and dark appearance.
public struct AdaptiveRGB: Hashable, Sendable {
    public let light: RGB
    public let dark: RGB

    public init(light: UInt32, dark: UInt32) {
        self.light = RGB(light)
        self.dark = RGB(dark)
    }
}

/// Every colour in the app. Views never use raw colours: they use these tokens
/// (through `Color.ds(_:)` in the app target) so that light/dark/contrast stay audited
/// in one place. Values are covered by `PaletteTests`.
public enum PaletteToken: String, CaseIterable, Sendable {
    // Neutrals — warm paper in light mode, soft charcoal (not pure black) in dark mode.
    case background
    case surface
    case surfaceSecondary
    case textPrimary
    case textSecondary
    case textTertiary
    case separator

    // Brand. "Iris" nods to the Brussels-Capital Region emblem and replaces default blue.
    case accent
    case onAccent

    // Categories — muted, earthy, never neon.
    case categoryRoad
    case categoryCleanliness
    case categoryInsecurity
    case categoryHarassment

    // Status
    case statusPending
    case statusConfirmed
    case statusSent
    case statusResolved

    // Emergency
    case danger
    case onDanger

    public var value: AdaptiveRGB {
        switch self {
        case .background:          AdaptiveRGB(light: 0xF6F4EF, dark: 0x141418)
        case .surface:             AdaptiveRGB(light: 0xFDFCF9, dark: 0x1D1D23)
        case .surfaceSecondary:    AdaptiveRGB(light: 0xECE9E2, dark: 0x27272E)
        case .textPrimary:         AdaptiveRGB(light: 0x1C1B22, dark: 0xF2F0EB)
        case .textSecondary:       AdaptiveRGB(light: 0x55525F, dark: 0xB6B3BE)
        case .textTertiary:        AdaptiveRGB(light: 0x67646F, dark: 0x9B98A5)
        case .separator:           AdaptiveRGB(light: 0xD9D5CC, dark: 0x34343C)

        case .accent:              AdaptiveRGB(light: 0x4A3F9E, dark: 0xAFA4F0)
        case .onAccent:            AdaptiveRGB(light: 0xFFFFFF, dark: 0x141418)

        case .categoryRoad:        AdaptiveRGB(light: 0x7C5110, dark: 0xE2B566)
        case .categoryCleanliness: AdaptiveRGB(light: 0x396445, dark: 0x8FC29D)
        case .categoryInsecurity:  AdaptiveRGB(light: 0x993C2A, dark: 0xEE9481)
        case .categoryHarassment:  AdaptiveRGB(light: 0x7D3E71, dark: 0xD79BCB)

        case .statusPending:       AdaptiveRGB(light: 0x55525F, dark: 0xB6B3BE)
        case .statusConfirmed:     AdaptiveRGB(light: 0x4A3F9E, dark: 0xAFA4F0)
        case .statusSent:          AdaptiveRGB(light: 0x2B626C, dark: 0x86C3CC)
        case .statusResolved:      AdaptiveRGB(light: 0x2C6541, dark: 0x8BCB9F)

        case .danger:              AdaptiveRGB(light: 0xB3261E, dark: 0xC8372D)
        case .onDanger:            AdaptiveRGB(light: 0xFFFFFF, dark: 0xFFFFFF)
        }
    }

    /// Opacity used when a token tints a background (chips, badges, banners).
    public static let tintAlpha = 0.14
    /// Opacity used for zone fills on the map, scaled by zone intensity.
    public static let zoneFillAlpha: ClosedRange<Double> = 0.22...0.50
}
