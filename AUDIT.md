# Self-audit

## How this audit was done (read this first)

The project was built in a Linux container, where Xcode cannot run. No screen has been
rendered and **the iOS app target has not been compiled.** This audit is therefore a
**code-level audit** of every screen, backed by every mechanical check that could run
here:

| Check | Tool | Result |
|---|---|---|
| Colour contrast, all tokens, light + dark, every surface | `PaletteTests` (Swift Testing) | pass |
| Zone/chart colours: colour-blind separation (all pairs), normal vision, 3:1 | dataviz palette validator | pass |
| Colour pairs used outside the tokens (glyphs on marks, outlined buttons, timeline) | contrast script | 2 failures → fixed |
| Off-grid spacing, fixed font sizes, raw animations | grep scans | findings → fixed |
| Every user-facing string in the catalog, translated FR/NL/EN, placeholders consistent | `Tools/l10n/check.py` | 342/342, 0 errors |
| Swift syntax of all 43 app files | `swiftc -parse` | pass |
| Initializer access with private properties (a common SwiftUI build break) | compiler experiment | no issue |
| Core and backend logic | 32 Swift tests | pass |
| Database, RLS, thresholds, trust, privacy | 77 pgTAP tests | pass |

Every view ships `#Preview`s in light, dark, AX5, French, Dutch and English
(`PreviewMatrix`). The visual pass to finish on a Mac is listed at the end.

Order, as requested: **type scale → spacing → hierarchy → contrast → motion → density**,
then VoiceOver and tap targets. Line numbers refer to the file **before** the fix.

## 1. Type scale

| # | Where | Issue | Fix | Status |
|---|---|---|---|---|
| T1 | `App/Features/Report/ReportFlowView.swift:218` | Map pin glyph at a fixed 36 pt ignores Dynamic Type | `@ScaledMetric(relativeTo: .title) pinSize`; offset `-pinSize / 2` (was `-18`, line 221) so the tip stays on the centre | Fixed |
| T2 | `App/Features/Report/ReportFlowView.swift:438` | Success glyph fixed at 64 pt | `@ScaledMetric(relativeTo: .largeTitle) heroSize` | Fixed |
| T3 | `App/Features/Help/WalkHomeView.swift:113` | "Arrived" glyph fixed at 64 pt | Same scaled metric | Fixed |
| T4 | `App/Features/Onboarding/OnboardingView.swift:44` | Page glyph fixed at 30 pt | `@ScaledMetric(relativeTo: .title)`, capped at 48 pt inside the illustration | Fixed |
| T5 | `App/DesignSystem/Components/EmergencyCallButton.swift:26,31` | At accessibility sizes the scaled "112" and both labels share one row; `minimumScaleFactor(0.8)` shrank text | `AnyLayout`: horizontal by default, vertical at accessibility sizes; scale factor removed | Fixed |
| T6 | `App/Features/Share/ShareCard.swift` | Fixed point sizes | Intentional: it renders a fixed 1080 × 1350 image; Dynamic Type is pinned to `.large` in the renderer | No change |

The scale itself (`DSTextStyle`): 11 styles, all mapped to system text styles, so all
of them scale to AX5. Numbers use SF Pro Rounded with monospaced digits.

## 2. Spacing

| # | Where | Issue | Fix | Status |
|---|---|---|---|---|
| S1 | `App/DesignSystem/Components/Content.swift:58` | `ListRow` title/subtitle gap of 2 pt (off grid) | `Space.xs` (4 pt) | Fixed |
| S2 | `App/Features/FollowUp/FollowUpScreen.swift:201` | `NearbyRow`, same | `Space.xs` | Fixed |
| S3 | All other paddings and stacks | Scan found only tokens or 4 pt multiples (12 = `s + xs` for chip padding, as documented in `Layout.swift`) | — | OK |

## 3. Hierarchy

| # | Where | Issue | Fix | Status |
|---|---|---|---|---|
| H1 | `App/Features/Help/HelpScreen.swift:16,62` | Two competing headings: inline nav title "Aide" plus a display title "Besoin d'aide ?" | One large navigation title (`help.title`); content opens with the subtitle | Fixed |
| H2 | `App/Features/Help/WalkHomeView.swift:143` | The secondary "Send the link" sat above the primary "I'm home" | Primary first, then share, extend, stop | Fixed |
| H3 | Every screen | One filled primary per screen: Map → Report; Report → Continue/Send; Help → 112; zone sheet → Share (road/cleanliness only) | — | OK |

## 4. Contrast

| # | Where | Issue | Fix | Status |
|---|---|---|---|---|
| C1 | `App/DesignSystem/Components/EmergencyCallButton.swift:54` | Outlined buttons (101, support lines) used the red *fill* colour as text: **3.23:1** in dark mode (needs 4.5) | Text and icon use `categoryInsecurity` (7.34:1); the outline keeps `danger` | Fixed |
| C2 | `App/DesignSystem/Components/Feedback.swift:17` | Serious banner icon `danger` on its own tint: **3.00:1** in dark mode | `categoryInsecurity` (6.17:1) | Fixed |
| C3 | `App/Features/Report/ReportFlowView.swift` (note counter) | Over-limit counter used `danger` as text | `categoryInsecurity` | Fixed during build |
| C4 | `Packages/.../Palette.swift` | Light-mode coloured text on its own 14 % tint at 4.06–4.47:1 | Five light tokens darkened by the minimum that reaches 4.6:1 (unit test guards it) | Fixed during build |
| C5 | Map zones | Text-tuned category colours were too close for identity (sage/brick ΔE 5.8 for deuteranopes) | Separate `mark*` tokens found by OKLCH search: all-pairs CVD ΔE ≥ 10, normal ΔE ≥ 17, ≥ 3:1 on every surface; plus category glyphs when zoomed in | Fixed during build |

Verified by computation: glyph icons on mark colours ≥ 3.71:1 (light) / 3.97:1 (dark);
timeline icons ≥ 6.85:1; walk-ring strokes ≥ 3.53:1. Increase Contrast pulls secondary
text and hairlines towards the primary ink (`Colors.swift`).

## 5. Motion

| # | Where | Finding | Status |
|---|---|---|---|
| M1 | Whole app | Every animation goes through `Motion` (springs of 200/280/300 ms, never linear) or `dsAnimation`, which switches to a 180 ms ease-out cross-fade with Reduce Motion | OK |
| M2 | Report steps, "around me" rows | Slides become opacity-only with Reduce Motion | OK |
| M3 | `OTPCodeField` shake, `HexCluster` entrance | Skipped with Reduce Motion | OK |
| M4 | `App/Features/Report/ReportFlowView.swift:137` | Auto-advance after picking a category moves VoiceOver focus unexpectedly | Disabled while VoiceOver runs; Continue remains | Fixed |
| M5 | Haptics | Only on selection, commit, success, warning, error; the error haptic fires only when the error appears | OK |

## 6. Density

| # | Where | Issue | Fix | Status |
|---|---|---|---|---|
| D1 | `App/Features/Map/MapScreen.swift:56` | At AX5 the chips, filter pill and bottom bar would cover most of the map | Map chrome capped at `accessibility2` (as Apple Maps does); the zone list, fully dynamic, is the accessible way to browse | Fixed |
| D2 | `App/Features/Onboarding/OnboardingView.swift` | 200 pt illustration pushes text below the fold at accessibility sizes | 136 pt at accessibility sizes | Fixed |
| D3 | `App/Features/Map/FilterBar.swift:52` | `lineLimit(1)` would truncate "Sint-Lambrechts-Woluwe" | Text wraps; container is a capsule on one line and a soft rectangle when wrapped | Fixed |
| D4 | Zone sheet metrics | Row → column via `ViewThatFits` | — | OK |

## 7. VoiceOver

| # | Where | Finding | Status |
|---|---|---|---|
| V1 | `App/Features/Map/FilterBar.swift:65` | The filter button announced "filters" but not the current values | `accessibilityValue("30 days, Ixelles")` | Fixed |
| V2 | Map | Polygons are not accessibility elements: the map carries a label and a hint pointing to "Zones as a list", the equivalent table view | By design |
| V3 | All screens | Icon-only buttons labelled (list, locate); decorative images hidden; headers marked; chart bars carry label + value; gauge value exposed; OTP field labelled; selected chips/tiles/languages carry `.isSelected`; status timeline announces the current step | OK |

## 8. Tap targets

Everything interactive is ≥ 44 pt: chips 44, buttons 56, map buttons 48, Report 64,
rows 44–56, onboarding Skip 44, OTP field 56. Zone glyphs (24 pt) are not interactive;
taps go to the map. **OK.**

## 9. Localization (FR / NL / EN)

* 342 keys, all used, all translated, placeholders consistent. 3 unused keys removed.
* Plurals vary on a single argument only; sentences embed pluralised `Text`.
* A `Text(cond ? "a" : "b")` ternary would have been unlocalised (`String` overload).
  Fixed in `SignInView.swift:30`.
* Long Dutch words: no fixed text widths, wrapping everywhere, 2 × 2 grids collapse to
  one column at accessibility sizes, previews show NL next to FR/EN.
* French uses "vous" throughout, except the walk-home message the user sends to a
  friend ("Suis mon trajet"), which is intentionally "tu".

## 10. Build safety (Swift 6)

* Initializer access: SwiftUI views with only property-wrapped private state keep an
  accessible memberwise init; plain `private var` with defaults would not. Scan: none.
* Images crossing into background tasks: Vision now receives JPEG `Data`; the two
  image-holding structs are `@unchecked Sendable` with the reason documented.
* Release builds fail if Supabase keys are missing (pre-build script), so demo data can
  never ship.

## To finish on a Mac (cannot be done in this container)

1. `xcodebuild -scheme Brusk -destination 'platform=iOS Simulator,name=iPhone 17'`; fix
   any SDK-level compile errors (the app target was never compiled; logic packages were).
2. Open each `#Preview` (light, dark, AX5, FR, NL, EN) and check clipping, alignment and
   wrapping by eye.
3. Run with VoiceOver on: onboarding → report → follow-up → help.
4. Accessibility Inspector audit on every screen.
5. Liquid Glass (iOS 26) vs material fallback (iOS 18): compare the map chrome on both.
6. Test the report flow against a stopwatch: the target is under 20 seconds.
