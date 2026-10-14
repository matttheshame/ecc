import BruskCore
import SwiftUI

/// The map as a list: the accessible alternative to coloured polygons (VoiceOver,
/// colour blindness, quick scanning). Same data, sorted by most recent activity.
struct ZoneListView: View {
    let zones: [Zone]
    let onSelect: (Zone) -> Void
    @Environment(\.dismiss) private var dismiss
    @Environment(LanguageStore.self) private var language

    var body: some View {
        NavigationStack {
            Group {
                if zones.isEmpty {
                    StateView(kind: .empty(symbol: "checkmark.seal", titleKey: "map.status.empty", messageKey: "map.list.emptyMessage"))
                } else {
                    List(zones.sorted { $0.latestAt > $1.latestAt }) { zone in
                        Button { onSelect(zone) } label: {
                            ListRow(
                                systemImage: zone.category.symbolName,
                                tint: zone.category.color,
                                title: Text(LocalizedStringKey(zone.category.titleKey)),
                                subtitle: subtitle(for: zone)
                            ) {
                                Image(systemName: "chevron.right")
                                    .font(.footnote.weight(.semibold))
                                    .foregroundStyle(Color.ds(.textTertiary))
                                    .accessibilityHidden(true)
                            }
                        }
                        .listRowBackground(Color.ds(.surface))
                    }
                    .scrollContentBackground(.hidden)
                }
            }
            .background(Color.ds(.background))
            .navigationTitle(Text("map.list.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button { dismiss() } label: { Text("common.done") }
                }
            }
        }
    }

    private func subtitle(for zone: Zone) -> Text {
        // Plurals stay in single-argument strings; sentences embed them as Text.
        let count = Text("zone.confirmedCount \(zone.confirmedCount)")
        if let commune = Commune.with(code: zone.communeCode)?.name(in: language.resolved) {
            return Text("zone.list.subtitle \(count) \(commune)")
        }
        return count
    }
}
