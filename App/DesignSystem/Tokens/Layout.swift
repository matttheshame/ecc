import SwiftUI

/// 8 pt grid. `xs` (4 pt) is the only half step, reserved for tight inner gaps
/// (icon ↔ label, badge padding).
enum Space {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 16
    static let l: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
    static let xxxl: CGFloat = 64

    /// Horizontal screen margin.
    static let gutter: CGFloat = 16
    /// Apple HIG minimum hit target.
    static let minTapTarget: CGFloat = 44
}

/// Continuous ("squircle") corner radii.
enum Radius {
    static let small: CGFloat = 8
    static let medium: CGFloat = 16
    static let large: CGFloat = 24
    static let extraLarge: CGFloat = 32

    static func shape(_ radius: CGFloat) -> RoundedRectangle {
        RoundedRectangle(cornerRadius: radius, style: .continuous)
    }
}

/// Fixed control heights, all multiples of 8.
enum ControlSize {
    static let button: CGFloat = 56
    static let floatingAction: CGFloat = 64
    static let chip: CGFloat = 44
    static let row: CGFloat = 56
}
