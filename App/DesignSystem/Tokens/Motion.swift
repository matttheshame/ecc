import SwiftUI

/// Springs only, all under 300 ms, never linear. With Reduce Motion on, movement is
/// replaced by a short ease-out cross-fade.
enum Motion {
    /// Press states, toggles. 200 ms, no bounce.
    static let quick: Animation = .spring(duration: 0.2, bounce: 0)
    /// Default for layout changes and sheets' inner content. 280 ms, slight bounce.
    static let standard: Animation = .spring(duration: 0.28, bounce: 0.1)
    /// Confirmations and success moments. 300 ms, livelier.
    static let emphasized: Animation = .spring(duration: 0.3, bounce: 0.22)
    /// Reduce Motion replacement.
    static let reduced: Animation = .easeOut(duration: 0.18)
}

private struct DSAnimation<Value: Equatable>: ViewModifier {
    let animation: Animation
    let value: Value
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content.animation(reduceMotion ? Motion.reduced : animation, value: value)
    }
}

extension View {
    /// `.animation(_:value:)` that respects Reduce Motion.
    func dsAnimation<Value: Equatable>(_ animation: Animation = Motion.standard, value: Value) -> some View {
        modifier(DSAnimation(animation: animation, value: value))
    }
}

/// `withAnimation` that respects Reduce Motion.
@MainActor
func withMotion<Result>(_ animation: Animation = Motion.standard, reduceMotion: Bool, _ body: () throws -> Result) rethrows -> Result {
    try withAnimation(reduceMotion ? Motion.reduced : animation, body)
}

/// Haptics on key actions only: selecting a category, committing a report, success,
/// warnings and errors. Never on scroll or passive updates.
enum Haptic {
    case selection
    case commit
    case success
    case warning
    case error

    var feedback: SensoryFeedback {
        switch self {
        case .selection: .selection
        case .commit: .impact(weight: .medium)
        case .success: .success
        case .warning: .warning
        case .error: .error
        }
    }
}

extension View {
    func haptic<Trigger: Equatable>(_ haptic: Haptic, trigger: Trigger) -> some View {
        sensoryFeedback(haptic.feedback, trigger: trigger)
    }
}
