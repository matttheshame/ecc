import BruskCore
import MapKit
import SwiftUI

/// What a share card says (spec §7). Never personal data, never an unblurred photo.
/// Only road and cleanliness can be shared: positive pressure on a *service*. Sharing
/// insecurity or harassment about a named street would stigmatise it (spec §8).
struct ShareCardContent: Sendable {
    enum Kind: Sendable, Equatable {
        /// "Reported 12 days ago, still unresolved."
        case unresolved(days: Int)
        /// "Resolved — 5 reports fixed here."
        case resolved(count: Int)
        /// "Cleanliness score of the neighbourhood this month: 72/100."
        case score(Int)
    }

    let kind: Kind
    let category: ReportCategory
    let streetName: String?
    let communeName: String?
    let link: URL
    /// Area drawn on the card's map: a zone outline, or a coarse hexagon around a
    /// rounded coordinate for an individual report, so no exact point is ever shown.
    let area: [GeoCoordinate]

    static func isShareable(_ category: ReportCategory) -> Bool { category.allowsAutomaticRouting }

    /// For one's own report: snap to ~150 m before drawing anything.
    static func coarseArea(around coordinate: GeoCoordinate) -> [GeoCoordinate] {
        let snapped = GeoCoordinate(
            latitude: (coordinate.latitude / 0.0015).rounded() * 0.0015,
            longitude: (coordinate.longitude / 0.002).rounded() * 0.002
        )
        return Geometry.hexagon(around: snapped, edgeMeters: 160)
    }
}

/// A map snapshot with the area's outline already projected into image coordinates.
/// `@unchecked`: immutable after creation; crosses from the snapshot callback once.
struct CardMap: @unchecked Sendable {
    let image: UIImage
    let outline: [CGPoint]
}

@MainActor
enum ShareCardRenderer {
    static let cardSize = CGSize(width: 360, height: 450)
    static let mapHeight: CGFloat = 210

    static func render(_ content: ShareCardContent, locale: Locale) async -> UIImage? {
        let map = await snapshot(of: content.area, size: CGSize(width: cardSize.width, height: mapHeight))
        let card = ShareCardView(content: content, map: map)
            .environment(\.locale, locale)
            .environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .large)
        let renderer = ImageRenderer(content: card)
        renderer.scale = 3 // 1080 × 1350 px, the 4:5 format X displays uncropped
        renderer.proposedSize = ProposedViewSize(cardSize)
        return renderer.uiImage
    }

    private static func snapshot(of area: [GeoCoordinate], size: CGSize) async -> CardMap? {
        guard let center = Geometry.centroid(of: area) else { return nil }
        let options = MKMapSnapshotter.Options()
        options.region = MKCoordinateRegion(center: center.clCoordinate, latitudinalMeters: 900, longitudinalMeters: 900)
        options.size = size
        options.traitCollection = UITraitCollection { traits in
            traits.userInterfaceStyle = .light
            traits.displayScale = 3
        }
        let configuration = MKStandardMapConfiguration(elevationStyle: .flat, emphasisStyle: .muted)
        configuration.pointOfInterestFilter = .excludingAll
        options.preferredConfiguration = configuration

        let snapshotter = MKMapSnapshotter(options: options)
        return await withCheckedContinuation { continuation in
            snapshotter.start(with: .main) { snapshot, _ in
                guard let snapshot else {
                    continuation.resume(returning: nil)
                    return
                }
                let points = area.map { snapshot.point(for: $0.clCoordinate) }
                continuation.resume(returning: CardMap(image: snapshot.image, outline: points))
            }
        }
    }
}

/// The card itself, laid out at a fixed 360 × 450 pt (rendered at 3×).
struct ShareCardView: View {
    let content: ShareCardContent
    let map: CardMap?

    private var color: Color { content.category.color }
    private var markColor: Color { content.category.markColor }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            mapHeader
            VStack(alignment: .leading, spacing: Space.s + Space.xs) {
                HStack(spacing: Space.s) {
                    Image(systemName: content.category.symbolName)
                    Text(LocalizedStringKey(content.category.titleKey))
                }
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(color)

                headline

                if let place = placeText {
                    Label { place } icon: { Image(systemName: "mappin.and.ellipse") }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(Color.ds(.textSecondary))
                        .lineLimit(2)
                }

                Spacer(minLength: 0)

                HStack(alignment: .firstTextBaseline) {
                    Text("app.name")
                        .font(.system(size: 15, weight: .bold))
                        .foregroundStyle(Color.ds(.accent))
                    Text("app.tagline")
                        .font(.system(size: 13))
                        .foregroundStyle(Color.ds(.textSecondary))
                    Spacer()
                    Text(verbatim: content.link.host() ?? DeepLink.universalHost)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.ds(.textSecondary))
                }
            }
            .padding(Space.l)
        }
        .frame(width: ShareCardRenderer.cardSize.width, height: ShareCardRenderer.cardSize.height)
        .background(Color.ds(.surface))
    }

    private var mapHeader: some View {
        ZStack(alignment: .topLeading) {
            if let map {
                Image(uiImage: map.image)
                    .resizable()
                    .frame(width: ShareCardRenderer.cardSize.width, height: ShareCardRenderer.mapHeight)
                Path { path in
                    path.addLines(map.outline)
                    path.closeSubpath()
                }
                .fill(markColor.opacity(0.35))
                Path { path in
                    path.addLines(map.outline)
                    path.closeSubpath()
                }
                .stroke(markColor, lineWidth: 2.5)
            } else {
                LinearGradient(colors: [markColor.opacity(0.35), markColor.opacity(0.1)], startPoint: .top, endPoint: .bottom)
            }
            LinearGradient(colors: [.clear, Color.ds(.surface)], startPoint: .center, endPoint: .bottom)
        }
        .frame(width: ShareCardRenderer.cardSize.width, height: ShareCardRenderer.mapHeight)
        .clipped()
    }

    @ViewBuilder
    private var headline: some View {
        switch content.kind {
        case .unresolved(let days):
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("share.card.days \(days)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ds(.textPrimary))
                Text("share.card.unresolved.caption")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.ds(.textPrimary))
            }
        case .resolved(let count):
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("share.card.resolved.title")
                    .font(.system(size: 40, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ds(.statusResolved))
                Text("share.card.resolved.caption \(count)")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.ds(.textPrimary))
            }
        case .score(let score):
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("share.card.score \(score)")
                    .font(.system(size: 44, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.ds(.textPrimary))
                Text(LocalizedStringKey(scoreCaptionKey))
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(Color.ds(.textPrimary))
            }
        }
    }

    private var scoreCaptionKey: String {
        content.category == .road ? "share.card.score.caption.road" : "share.card.score.caption.cleanliness"
    }

    private var placeText: Text? {
        switch (content.streetName, content.communeName) {
        case let (street?, commune?): Text("share.card.place \(street) \(commune)")
        case let (street?, nil): Text(verbatim: street)
        case let (nil, commune?): Text(verbatim: commune)
        case (nil, nil): nil
        }
    }
}

/// Preview of the rendered card with the system share sheet (X, Messages…).
struct ShareCardSheet: View {
    let content: ShareCardContent
    @Environment(\.locale) private var locale
    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: Space.l) {
                    Group {
                        if let image {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .clipShape(Radius.shape(Radius.large))
                                .elevation(.raised)
                                .accessibilityLabel(Text("share.preview.a11y"))
                                .transition(.opacity.combined(with: .scale(scale: 0.98)))
                        } else {
                            StateView(kind: .loading)
                                .frame(minHeight: 320)
                        }
                    }
                    .dsAnimation(Motion.standard, value: image == nil)

                    if let image {
                        ShareLink(
                            item: Image(uiImage: image),
                            subject: Text("app.name"),
                            message: message,
                            preview: SharePreview(Text("share.preview.title"), image: Image(uiImage: image))
                        ) {
                            Label("share.onX", systemImage: "square.and.arrow.up")
                        }
                        .buttonStyle(DSButtonStyle(kind: .primary))
                    }

                    Label("share.privacy.note", systemImage: "lock.shield")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ds(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.gutter)
            }
            .background(Color.ds(.background))
            .navigationTitle(Text("share.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button { dismiss() } label: { Text("common.close") }
                }
            }
        }
        .task { image = await ShareCardRenderer.render(content, locale: locale) }
    }

    private var message: Text {
        let link = content.link.absoluteString
        // Plurals stay in single-argument strings; sentences embed them as Text.
        switch content.kind {
        case .unresolved(let days):
            let age = Text("common.days \(days)")
            return Text("share.message.unresolved \(age) \(link)")
        case .resolved(let count):
            let fixed = Text("share.card.resolved.caption \(count)")
            return Text("share.message.resolved \(fixed) \(link)")
        case .score(let score):
            return Text("share.message.score \(score) \(link)")
        }
    }
}

#Preview("Share card — unresolved") {
    PreviewMatrix {
        ShareCardView(
            content: ShareCardContent(
                kind: .unresolved(days: 12), category: .cleanliness, streetName: "Rue Haute", communeName: "Bruxelles",
                link: DeepLink.zone(ZoneID(category: .cleanliness, hexI: 1, hexJ: 2)).shareURL,
                area: Geometry.hexagon(around: Brussels.center, edgeMeters: 120)
            ),
            map: nil
        )
        .environment(\.colorScheme, .light)
    }
}

#Preview("Share card — score & resolved") {
    PreviewMatrix(languages: [.nl]) {
        VStack {
            ShareCardView(
                content: ShareCardContent(
                    kind: .score(72), category: .cleanliness, streetName: nil, communeName: "Sint-Gillis",
                    link: DeepLink.zone(ZoneID(category: .cleanliness, hexI: 1, hexJ: 2)).shareURL, area: []
                ),
                map: nil
            )
            ShareCardView(
                content: ShareCardContent(
                    kind: .resolved(count: 5), category: .road, streetName: "Chaussée de Waterloo", communeName: "Elsene",
                    link: DeepLink.zone(ZoneID(category: .road, hexI: 1, hexJ: 2)).shareURL, area: []
                ),
                map: nil
            )
        }
        .environment(\.colorScheme, .light)
    }
}
