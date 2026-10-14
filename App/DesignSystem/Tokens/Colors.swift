import BruskCore
import SwiftUI
import UIKit

// Colour tokens. Values live in `BruskCore.PaletteToken` so they are unit-tested for
// WCAG AA in light and dark mode. Never use raw colours or `.blue` in views.

extension Color {
    static func ds(_ token: PaletteToken) -> Color { Color(uiColor: .ds(token)) }
}

extension UIColor {
    static func ds(_ token: PaletteToken) -> UIColor {
        UIColor { traits in
            let isDark = traits.userInterfaceStyle == .dark
            var rgb = isDark ? token.value.dark : token.value.light
            if traits.accessibilityContrast == .high, let stronger = Self.increasedContrast(token, isDark: isDark) {
                rgb = stronger
            }
            return UIColor(red: rgb.red, green: rgb.green, blue: rgb.blue, alpha: 1)
        }
    }

    /// Settings → Accessibility → Increase Contrast: secondary text and hairlines move
    /// towards the primary ink.
    private static func increasedContrast(_ token: PaletteToken, isDark: Bool) -> RGB? {
        let ink = isDark ? PaletteToken.textPrimary.value.dark : PaletteToken.textPrimary.value.light
        switch token {
        case .textSecondary, .textTertiary, .statusPending:
            let base = isDark ? token.value.dark : token.value.light
            return ink.over(base, alpha: 0.6)
        case .separator:
            let base = isDark ? token.value.dark : token.value.light
            return ink.over(base, alpha: 0.35)
        default:
            return nil
        }
    }
}

extension ReportCategory {
    var color: Color { .ds(paletteToken) }
}

extension ReportStatus {
    var color: Color { .ds(paletteToken) }
}
