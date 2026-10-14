import BruskCore
import SwiftUI

/// Every token and component on one scrollable page, with an instant language switch.
/// Used for design reviews and the self-audit (Settings → About, Debug builds only).
struct DesignSystemGallery: View {
    @Environment(LanguageStore.self) private var language
    @State private var selectedCategories: Set<ReportCategory> = [.road, .harassment]
    @State private var tile: ReportCategory? = .cleanliness
    @State private var code = "48"
    @State private var loading = false

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Space.xl) {
                Picker(selection: Binding(get: { language.selection }, set: { language.select($0) })) {
                    ForEach(AppLanguage.allCases) { Text($0.titleKey).tag($0) }
                } label: {
                    Text("settings.language.title")
                }
                .pickerStyle(.segmented)

                section("settings.gallery.typography") {
                    VStack(alignment: .leading, spacing: Space.s) {
                        ForEach(Array(DSTextStyle.allCases.enumerated()), id: \.offset) { _, style in
                            Text("app.tagline").textStyle(style)
                        }
                    }
                }

                section("settings.gallery.colors") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 64), spacing: Space.s)], spacing: Space.s) {
                        ForEach(PaletteToken.allCases, id: \.self) { token in
                            Radius.shape(Radius.small)
                                .fill(Color.ds(token))
                                .frame(height: 48)
                                .overlay(Radius.shape(Radius.small).strokeBorder(Color.ds(.separator), lineWidth: 0.5))
                                .accessibilityLabel(Text(verbatim: token.rawValue))
                        }
                    }
                }

                section("settings.gallery.components") {
                    VStack(alignment: .leading, spacing: Space.m) {
                        ScrollView(.horizontal, showsIndicators: false) {
                            HStack(spacing: Space.s) {
                                ForEach(ReportCategory.allCases) { category in
                                    CategoryChip(category: category, isSelected: selectedCategories.contains(category)) {
                                        if selectedCategories.contains(category) {
                                            selectedCategories.remove(category)
                                        } else {
                                            selectedCategories.insert(category)
                                        }
                                    }
                                }
                            }
                        }
                        Grid(horizontalSpacing: Space.s + Space.xs, verticalSpacing: Space.s + Space.xs) {
                            GridRow {
                                CategoryTile(category: .road, isSelected: tile == .road) { tile = .road }
                                CategoryTile(category: .cleanliness, isSelected: tile == .cleanliness) { tile = .cleanliness }
                            }
                        }
                        DSButton("common.send", systemImage: "paperplane", isLoading: loading) {
                            loading = true
                            Task {
                                try? await Task.sleep(for: .seconds(1))
                                loading = false
                            }
                        }
                        DSButton("common.retry", kind: .secondary) {}
                        FloatingReportButton {}
                        HStack { ForEach(ReportStatus.allCases, id: \.self) { StatusBadge(status: $0) } }
                        StatusTimeline(status: .confirmed)
                        OTPCodeField(code: $code)
                        Banner(kind: .serious, titleKey: "help.112.title", messageKey: "help.112.detail")
                        StateView(kind: .error(messageKey: "error.network"), actionKey: "common.retry") {}
                        EmergencyCallButton(contact: EmergencyDirectory.emergency)
                        DemoDataPill()
                    }
                }
            }
            .padding(Space.gutter)
        }
        .background(Color.ds(.background))
        .navigationTitle(Text("settings.gallery.title"))
    }

    private func section<Content: View>(_ titleKey: LocalizedStringKey, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: Space.m) {
            SectionHeader(titleKey)
            content()
        }
    }
}

#Preview("Gallery") {
    let environment = AppEnvironment.preview()
    NavigationStack { DesignSystemGallery() }
        .environment(environment.language)
}

#Preview("Gallery — dark, AX5") {
    let environment = AppEnvironment.preview()
    NavigationStack { DesignSystemGallery() }
        .environment(environment.language)
        .preferredColorScheme(.dark)
        .previewAccessibilitySize()
}
