import BruskCore
import SwiftUI

/// Renders the same content in French, Dutch and English, stacked, so every component
/// preview shows all three languages at once (long Dutch compounds included).
struct PreviewMatrix<Content: View>: View {
    var languages: [LanguageCode] = LanguageCode.allCases
    @ViewBuilder var content: () -> Content

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.l) {
                ForEach(languages, id: \.self) { language in
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(verbatim: language.rawValue.uppercased())
                            .font(.caption.monospaced().weight(.semibold))
                            .foregroundStyle(Color.ds(.textTertiary))
                        content()
                            .environment(\.locale, Locale(identifier: language.formattingLocaleIdentifier))
                    }
                }
            }
            .padding(Space.gutter)
        }
        .background(Color.ds(.background))
    }
}

extension View {
    /// Preview helper: largest accessibility text size.
    func previewAccessibilitySize() -> some View {
        environment(\.dynamicTypeSize, .accessibility5)
    }
}
