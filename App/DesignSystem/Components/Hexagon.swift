import SwiftUI

/// Flat-topped hexagon, the app's zone motif (matches the map cells and the icon).
struct Hexagon: Shape {
    func path(in rect: CGRect) -> Path {
        let radius = min(rect.width / 2, rect.height / sqrt(3))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        var path = Path()
        for index in 0..<6 {
            let angle = Double(index) * .pi / 3
            let point = CGPoint(x: center.x + radius * cos(angle), y: center.y + radius * sin(angle))
            if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

/// A small cluster of hexagons in the four category colours: the brand illustration.
struct HexCluster: View {
    var size: CGFloat = 220
    var highlight: Color?
    @State private var appeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var cells: [(x: CGFloat, y: CGFloat, color: Color, opacity: Double)] {
        let palette: [Color] = [.ds(.markRoad), .ds(.markCleanliness), .ds(.markInsecurity), .ds(.markHarassment)]
        return [
            (0, 0, highlight ?? .ds(.accent), 1),
            (0, -1, palette[0], 0.55), (0.75, -0.5, palette[1], 0.45), (0.75, 0.5, palette[2], 0.35),
            (0, 1, palette[3], 0.5), (-0.75, 0.5, palette[0], 0.3), (-0.75, -0.5, palette[1], 0.6),
        ]
    }

    var body: some View {
        let cell = size / 3.2
        let step = cell * sqrt(3) / 2 * 1.08
        ZStack {
            ForEach(Array(cells.enumerated()), id: \.offset) { index, item in
                Hexagon()
                    .fill(item.color.opacity(item.opacity))
                    .frame(width: cell, height: cell * sqrt(3) / 2)
                    .offset(x: item.x * cell * 1.08, y: item.y * step)
                    .scaleEffect(appeared || reduceMotion ? 1 : 0.6)
                    .opacity(appeared || reduceMotion ? 1 : 0)
                    .animation(reduceMotion ? nil : Motion.emphasized.delay(Double(index) * 0.03), value: appeared)
            }
        }
        .frame(width: size, height: size * 0.9)
        .onAppear { appeared = true }
        .accessibilityHidden(true)
    }
}

#Preview("Hex cluster") {
    VStack(spacing: Space.xl) {
        HexCluster()
        HexCluster(size: 120, highlight: .ds(.markCleanliness))
    }
    .padding()
    .background(Color.ds(.background))
}
