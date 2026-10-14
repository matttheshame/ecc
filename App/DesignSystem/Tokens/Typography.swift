import SwiftUI

/// SF Pro type scale. Every style maps to a system text style, so Dynamic Type scales
/// it up to the accessibility sizes without extra work. Numbers use SF Pro Rounded with
/// monospaced digits so counters don't jitter.
enum DSTextStyle: CaseIterable {
    /// Screen hero: onboarding, big counters' captions. 34 pt bold.
    case display
    /// Screen and sheet titles. 22 pt bold.
    case title
    /// Card titles, row titles. 17 pt semibold.
    case headline
    /// Reading text. 17 pt regular.
    case body
    /// Button labels, emphasised body. 17 pt semibold.
    case bodyEmphasized
    /// Secondary lines in cards. 16 pt.
    case callout
    /// Row subtitles, chip labels. 15 pt.
    case subheadline
    /// Hints, legal lines. 13 pt.
    case footnote
    /// Badges, metadata. 12 pt medium.
    case caption
    /// Big numbers ("12 days"). 34 pt rounded semibold.
    case metric
    /// Small numbers in tiles. 20 pt rounded semibold.
    case metricSmall

    var font: Font {
        switch self {
        case .display: .system(.largeTitle, design: .default, weight: .bold)
        case .title: .system(.title2, design: .default, weight: .bold)
        case .headline: .system(.headline, design: .default, weight: .semibold)
        case .body: .system(.body)
        case .bodyEmphasized: .system(.body, design: .default, weight: .semibold)
        case .callout: .system(.callout)
        case .subheadline: .system(.subheadline)
        case .footnote: .system(.footnote)
        case .caption: .system(.caption, design: .default, weight: .medium)
        case .metric: .system(.largeTitle, design: .rounded, weight: .semibold).monospacedDigit()
        case .metricSmall: .system(.title3, design: .rounded, weight: .semibold).monospacedDigit()
        }
    }

    /// Extra line spacing for multi-line reading text.
    var lineSpacing: CGFloat {
        switch self {
        case .body, .callout, .subheadline: 2
        default: 0
        }
    }
}

extension View {
    func textStyle(_ style: DSTextStyle) -> some View {
        font(style.font).lineSpacing(style.lineSpacing)
    }
}
