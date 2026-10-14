import Testing
@testable import BruskCore

/// WCAG AA is a hard requirement (prompt + spec). These tests fail the build if a token
/// edit breaks contrast in light or dark mode.
@Suite("Palette contrast")
struct PaletteTests {
    static let surfaces: [PaletteToken] = [.background, .surface, .surfaceSecondary]
    static let textTokens: [PaletteToken] = [
        .textPrimary, .textSecondary, .textTertiary, .accent,
        .categoryRoad, .categoryCleanliness, .categoryInsecurity, .categoryHarassment,
        .statusPending, .statusConfirmed, .statusSent, .statusResolved,
    ]

    @Test("Text tokens reach 4.5:1 on every surface, light and dark", arguments: textTokens)
    func textOnSurfaces(token: PaletteToken) {
        for surface in Self.surfaces {
            let light = WCAG.contrast(token.value.light, surface.value.light)
            let dark = WCAG.contrast(token.value.dark, surface.value.dark)
            #expect(light >= WCAG.textMinimum, "\(token) on \(surface) light = \(light)")
            #expect(dark >= WCAG.textMinimum, "\(token) on \(surface) dark = \(dark)")
        }
    }

    @Test("Coloured text stays AA on its own tinted chip background")
    func textOnOwnTint() {
        let coloured: [PaletteToken] = [
            .accent, .categoryRoad, .categoryCleanliness, .categoryInsecurity, .categoryHarassment,
            .statusPending, .statusConfirmed, .statusSent, .statusResolved,
        ]
        for token in coloured {
            for surface in Self.surfaces {
                let tintLight = token.value.light.over(surface.value.light, alpha: PaletteToken.tintAlpha)
                let tintDark = token.value.dark.over(surface.value.dark, alpha: PaletteToken.tintAlpha)
                #expect(WCAG.contrast(token.value.light, tintLight) >= WCAG.textMinimum, "\(token) on tint over \(surface) light")
                #expect(WCAG.contrast(token.value.dark, tintDark) >= WCAG.textMinimum, "\(token) on tint over \(surface) dark")
            }
        }
    }

    @Test("Filled buttons: label on accent and on danger")
    func filledButtons() {
        #expect(WCAG.contrast(PaletteToken.onAccent.value.light, PaletteToken.accent.value.light) >= WCAG.textMinimum)
        #expect(WCAG.contrast(PaletteToken.onAccent.value.dark, PaletteToken.accent.value.dark) >= WCAG.textMinimum)
        #expect(WCAG.contrast(PaletteToken.onDanger.value.light, PaletteToken.danger.value.light) >= WCAG.textMinimum)
        #expect(WCAG.contrast(PaletteToken.onDanger.value.dark, PaletteToken.danger.value.dark) >= WCAG.textMinimum)
    }

    @Test("Separators are visible but quiet (non-text, decorative)")
    func separators() {
        let light = WCAG.contrast(PaletteToken.separator.value.light, PaletteToken.surface.value.light)
        let dark = WCAG.contrast(PaletteToken.separator.value.dark, PaletteToken.surface.value.dark)
        #expect(light > 1.2 && light < WCAG.nonTextMinimum)
        #expect(dark > 1.2 && dark < WCAG.nonTextMinimum)
    }

    @Test("Category colours are distinguishable from each other")
    func categoriesDistinct() {
        let cats = ReportCategory.allCases.map(\.paletteToken.value.light)
        #expect(Set(cats.map(\.description)).count == cats.count)
    }

    @Test("Known contrast values")
    func knownValues() {
        #expect(abs(WCAG.contrast(RGB(0x000000), RGB(0xFFFFFF)) - 21) < 0.01)
        #expect(abs(WCAG.contrast(RGB(0x777777), RGB(0xFFFFFF)) - 4.48) < 0.01)
    }
}
