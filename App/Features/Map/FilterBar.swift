import BruskCore
import SwiftUI

/// Top of the map: category chips (which double as the legend), then period and
/// commune (spec §5 écran 1: "par type, par période, par commune").
struct FilterBar: View {
    let model: MapViewModel
    @Environment(LanguageStore.self) private var language
    @State private var selectionTick = 0

    var body: some View {
        VStack(alignment: .leading, spacing: Space.s) {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: Space.s) {
                    ForEach(ReportCategory.allCases) { category in
                        CategoryChip(category: category, isSelected: model.filter.categories.contains(category)) {
                            selectionTick += 1
                            model.toggle(category)
                        }
                    }
                }
                .padding(.horizontal, Space.gutter)
            }
            .scrollClipDisabled()

            Menu {
                Picker(selection: Binding(get: { model.filter.period }, set: { model.setPeriod($0) })) {
                    ForEach(Period.allCases) { period in
                        Text(LocalizedStringKey(period.titleKey)).tag(period)
                    }
                } label: {
                    Label("map.filter.period", systemImage: "calendar")
                }
                .pickerStyle(.menu)

                Picker(selection: Binding(get: { model.filter.communeCode }, set: { model.setCommune($0) })) {
                    Text("map.filter.allCommunes").tag(String?.none)
                    ForEach(Commune.sorted(in: language.resolved)) { commune in
                        Text(verbatim: commune.name(in: language.resolved)).tag(Optional(commune.nisCode))
                    }
                } label: {
                    Label("map.filter.commune", systemImage: "building.2")
                }
                .pickerStyle(.menu)
            } label: {
                HStack(spacing: Space.s) {
                    Image(systemName: "line.3.horizontal.decrease")
                        .accessibilityHidden(true)
                    Text(LocalizedStringKey(model.filter.period.titleKey))
                    Text(verbatim: "·").accessibilityHidden(true)
                    communeLabel
                        .lineLimit(1)
                    Image(systemName: "chevron.down")
                        .font(.caption2.weight(.bold))
                        .accessibilityHidden(true)
                }
                .textStyle(.footnote)
                .fontWeight(.semibold)
                .foregroundStyle(Color.ds(.textPrimary))
                .padding(.horizontal, Space.s + Space.xs)
                .frame(minHeight: Space.minTapTarget)
                .glassSurface(in: Capsule(), interactive: true)
                .contentShape(Capsule())
            }
            .accessibilityLabel(Text("map.filter.a11y"))
            .padding(.horizontal, Space.gutter)
        }
        .padding(.vertical, Space.s)
        .haptic(.selection, trigger: selectionTick)
    }

    @ViewBuilder
    private var communeLabel: some View {
        if let commune = Commune.with(code: model.filter.communeCode) {
            Text(verbatim: commune.name(in: language.resolved))
        } else {
            Text("map.filter.allCommunes")
        }
    }
}
