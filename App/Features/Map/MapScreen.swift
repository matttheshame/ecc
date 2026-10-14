import BruskCore
import MapKit
import SwiftUI

/// Screen 1 (spec §5): the living map. Coloured hexagonal zones, never exact points.
struct MapScreen: View {
    @Environment(AppEnvironment.self) private var environment
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var model: MapViewModel

    init(environment: AppEnvironment) {
        _model = State(initialValue: MapViewModel(backend: environment.backend, store: environment.store))
    }

    var body: some View {
        @Bindable var model = model
        @Bindable var router = environment.router

        MapReader { proxy in
            Map(position: $model.camera) {
                UserAnnotation()
                ForEach(model.zones) { zone in
                    MapPolygon(coordinates: zone.outline.map(\.clCoordinate))
                        .foregroundStyle(zone.category.markColor.opacity(model.fillOpacity(for: zone)))
                        .stroke(zone.category.markColor, lineWidth: model.isSelected(zone) ? 3 : 1.5)
                }
                if model.showsGlyphs {
                    ForEach(model.zones) { zone in
                        Annotation(coordinate: zone.center.clCoordinate, anchor: .center) {
                            ZoneGlyph(category: zone.category)
                        } label: {
                            Text(LocalizedStringKey(zone.category.titleKey))
                        }
                        .annotationTitles(.hidden)
                    }
                }
            }
            .mapStyle(.standard(elevation: .flat, emphasis: .muted, pointsOfInterest: .excludingAll, showsTraffic: false))
            .mapControls {
                MapCompass()
                MapScaleView()
            }
            .onMapCameraChange(frequency: .onEnd) { context in
                model.cameraChanged(span: context.region.span)
            }
            .onTapGesture { point in
                if let coordinate = proxy.convert(point, from: .local) {
                    withMotion(Motion.standard, reduceMotion: reduceMotion) {
                        model.select(at: GeoCoordinate(coordinate))
                    }
                }
            }
            .accessibilityLabel(Text("map.a11y.label"))
            .accessibilityHint(Text("map.a11y.hint"))
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            FilterBar(model: model)
        }
        .overlay(alignment: .bottom) {
            bottomBar
        }
        .sheet(item: $model.selection) { selection in
            ZoneSheet(selection: selection)
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $model.isShowingList) {
            ZoneListView(zones: model.zones) { zone in
                model.isShowingList = false
                Task {
                    try? await Task.sleep(for: .milliseconds(350))
                    model.select(zone)
                }
            }
            .presentationDetents([.medium, .large])
        }
        .task { await model.load() }
        .onChange(of: router.pendingZone) { _, id in
            guard let id else { return }
            router.pendingZone = nil
            Task { await model.focus(on: id) }
        }
    }

    private var bottomBar: some View {
        VStack(spacing: Space.s + Space.xs) {
            statusPill
            HStack(alignment: .center, spacing: Space.m) {
                MapRoundButton(systemImage: "list.bullet", labelKey: "map.list.button") {
                    model.isShowingList = true
                }
                FloatingReportButton {
                    environment.session.requireSignIn { environment.router.isReporting = true }
                }
                MapRoundButton(systemImage: "location", labelKey: "map.locate.button") {
                    environment.location.requestPermission()
                    withMotion(Motion.standard, reduceMotion: reduceMotion) {
                        model.camera = .userLocation(fallback: .region(MapViewModel.brusselsRegion))
                    }
                }
            }
        }
        .padding(.horizontal, Space.gutter)
        .padding(.bottom, Space.m)
    }

    @ViewBuilder
    private var statusPill: some View {
        switch model.state {
        case .loading where model.zones.isEmpty:
            MapStatusPill(systemImage: nil, textKey: "common.loading", showsProgress: true)
        case .offline:
            MapStatusPill(systemImage: "wifi.slash", textKey: "map.status.offline")
        case .failed:
            Button {
                Task { await model.load() }
            } label: {
                MapStatusPill(systemImage: "arrow.clockwise", textKey: "map.status.failed")
            }
            .buttonStyle(PressableButtonStyle())
        case .loaded where model.zones.isEmpty:
            MapStatusPill(systemImage: "checkmark.seal", textKey: "map.status.empty")
        default:
            if model.isDemo {
                DemoDataPill()
            }
        }
    }
}

/// Category icon at a zone's centre when zoomed in (secondary encoding for colour-blind users).
private struct ZoneGlyph: View {
    let category: ReportCategory

    var body: some View {
        Image(systemName: category.symbolName)
            .font(.caption.weight(.bold))
            .foregroundStyle(Color.ds(.onAccent))
            .frame(width: 24, height: 24)
            .background(category.markColor, in: Circle())
            .overlay(Circle().strokeBorder(Color.ds(.surface), lineWidth: 2))
            .accessibilityHidden(true)
    }
}

/// 48 pt glass circle for secondary map actions.
struct MapRoundButton: View {
    let systemImage: String
    let labelKey: LocalizedStringKey
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.body.weight(.semibold))
                .foregroundStyle(Color.ds(.textPrimary))
                .frame(width: 48, height: 48)
                .glassSurface(in: Circle(), interactive: true)
                .contentShape(Circle())
        }
        .buttonStyle(PressableButtonStyle())
        .accessibilityLabel(Text(labelKey))
    }
}

private struct MapStatusPill: View {
    let systemImage: String?
    let textKey: LocalizedStringKey
    var showsProgress = false

    var body: some View {
        HStack(spacing: Space.s) {
            if showsProgress {
                ProgressView().controlSize(.small)
            } else if let systemImage {
                Image(systemName: systemImage).accessibilityHidden(true)
            }
            Text(textKey)
                .fixedSize(horizontal: false, vertical: true)
        }
        .textStyle(.footnote)
        .fontWeight(.medium)
        .foregroundStyle(Color.ds(.textPrimary))
        .padding(.horizontal, Space.m)
        .padding(.vertical, Space.s)
        .frame(minHeight: Space.minTapTarget)
        .glassSurface(in: Capsule())
        .transition(.move(edge: .bottom).combined(with: .opacity))
        .accessibilityElement(children: .combine)
    }
}

#Preview("Map") {
    let environment = AppEnvironment.preview()
    MapScreen(environment: environment)
        .environment(environment)
        .environment(environment.language)
}

#Preview("Map — dark, Dutch, AX3") {
    let environment = AppEnvironment.preview()
    MapScreen(environment: environment)
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "nl_BE"))
        .environment(\.dynamicTypeSize, .accessibility3)
        .preferredColorScheme(.dark)
}
