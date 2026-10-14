import SwiftUI

/// Three screens, privacy first. No account needed to finish: the map is open to all.
struct OnboardingView: View {
    let onFinish: () -> Void
    @State private var page = 0
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @ScaledMetric(relativeTo: .title) private var symbolSize: CGFloat = 30

    private struct Page: Identifiable {
        let id: Int
        let symbol: String
        let titleKey: LocalizedStringKey
        let bodyKey: LocalizedStringKey
        let footnoteKey: LocalizedStringKey?
    }

    private let pages = [
        Page(id: 0, symbol: "map", titleKey: "onboarding.map.title", bodyKey: "onboarding.map.body", footnoteKey: nil),
        Page(id: 1, symbol: "eye.slash", titleKey: "onboarding.privacy.title", bodyKey: "onboarding.privacy.body", footnoteKey: "onboarding.privacy.footnote"),
        Page(id: 2, symbol: "person.3", titleKey: "onboarding.neighbours.title", bodyKey: "onboarding.neighbours.body", footnoteKey: "onboarding.neighbours.footnote"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                if page < pages.count - 1 {
                    Button { onFinish() } label: { Text("common.skip") }
                        .textStyle(.bodyEmphasized)
                        .foregroundStyle(Color.ds(.accent))
                        .frame(minWidth: Space.minTapTarget, minHeight: Space.minTapTarget)
                }
            }
            .padding(.horizontal, Space.gutter)
            .frame(minHeight: Space.minTapTarget)

            TabView(selection: $page) {
                ForEach(pages) { item in
                    ScrollView {
                        VStack(alignment: .leading, spacing: Space.l) {
                            ZStack {
                                // Smaller illustration at accessibility sizes leaves room for the text.
                                HexCluster(size: dynamicTypeSize.isAccessibilitySize ? 136 : 200, highlight: .ds(.accent))
                                Image(systemName: item.symbol)
                                    .font(.system(size: min(symbolSize, 48), weight: .semibold))
                                    .foregroundStyle(Color.ds(.onAccent))
                                    .accessibilityHidden(true)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, Space.l)

                            Text(item.titleKey)
                                .textStyle(.display)
                                .foregroundStyle(Color.ds(.textPrimary))
                                .accessibilityAddTraits(.isHeader)
                            Text(item.bodyKey)
                                .textStyle(.body)
                                .foregroundStyle(Color.ds(.textSecondary))
                            if let footnote = item.footnoteKey {
                                Label { Text(footnote) } icon: { Image(systemName: "info.circle") }
                                    .textStyle(.footnote)
                                    .foregroundStyle(Color.ds(.textSecondary))
                            }
                        }
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.horizontal, Space.gutter)
                        .padding(.bottom, Space.l)
                    }
                    .tag(item.id)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .dsAnimation(Motion.standard, value: page)

            VStack(spacing: Space.m) {
                StepIndicator(current: page + 1, total: pages.count)
                    .frame(maxWidth: 120)
                DSButton(page == pages.count - 1 ? "onboarding.start" : "common.continue") {
                    if page == pages.count - 1 {
                        onFinish()
                    } else {
                        withMotion(Motion.standard, reduceMotion: reduceMotion) { page += 1 }
                    }
                }
            }
            .padding(.horizontal, Space.gutter)
            .padding(.bottom, Space.m)
        }
        .background(Color.ds(.background))
    }
}

#Preview("Onboarding") {
    OnboardingView {}
}

#Preview("Onboarding — dark, Dutch, AX5") {
    OnboardingView {}
        .environment(\.locale, Locale(identifier: "nl_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}

#Preview("Onboarding — French") {
    OnboardingView {}
        .environment(\.locale, Locale(identifier: "fr_BE"))
}
