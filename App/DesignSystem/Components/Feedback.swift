import BruskCore
import SwiftUI

// MARK: - Banner

/// Inline message. `serious` is reserved for the "help first" banner (spec §4.4).
struct Banner<Actions: View>: View {
    enum Kind {
        case info
        case warning
        case serious

        var color: Color {
            switch self {
            case .info: .ds(.accent)
            case .warning: .ds(.categoryRoad)
            // Text-grade red: the fill red is only 3.0:1 on its tint in dark mode.
            case .serious: .ds(.categoryInsecurity)
            }
        }

        var symbol: String {
            switch self {
            case .info: "info.circle.fill"
            case .warning: "exclamationmark.triangle.fill"
            case .serious: "cross.case.fill"
            }
        }
    }

    let kind: Kind
    let titleKey: LocalizedStringKey
    var messageKey: LocalizedStringKey?
    @ViewBuilder var actions: () -> Actions

    init(kind: Kind, titleKey: LocalizedStringKey, messageKey: LocalizedStringKey? = nil, @ViewBuilder actions: @escaping () -> Actions) {
        self.kind = kind
        self.titleKey = titleKey
        self.messageKey = messageKey
        self.actions = actions
    }

    var body: some View {
        HStack(alignment: .top, spacing: Space.s + Space.xs) {
            Image(systemName: kind.symbol)
                .font(.headline)
                .foregroundStyle(kind.color)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: Space.s) {
                VStack(alignment: .leading, spacing: Space.xs) {
                    Text(titleKey)
                        .textStyle(.headline)
                        .foregroundStyle(Color.ds(.textPrimary))
                    if let messageKey {
                        Text(messageKey)
                            .textStyle(.subheadline)
                            .foregroundStyle(Color.ds(.textSecondary))
                    }
                }
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityElement(children: .combine)
                actions()
            }
        }
        .padding(Space.m)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(kind.color.opacity(0.10), in: Radius.shape(Radius.medium))
        .background(Color.ds(.surface), in: Radius.shape(Radius.medium))
        .overlay(Radius.shape(Radius.medium).strokeBorder(kind.color.opacity(0.35), lineWidth: 1))
        .accessibilityElement(children: .contain)
    }
}

extension Banner where Actions == EmptyView {
    init(kind: Kind, titleKey: LocalizedStringKey, messageKey: LocalizedStringKey? = nil) {
        self.init(kind: kind, titleKey: titleKey, messageKey: messageKey) { EmptyView() }
    }
}

// MARK: - Loading / empty / error

/// One component for the three non-content states every list and sheet must handle.
struct StateView: View {
    enum Kind {
        case loading
        case empty(symbol: String, titleKey: LocalizedStringKey, messageKey: LocalizedStringKey?)
        case error(messageKey: LocalizedStringKey)
        case offline
    }

    let kind: Kind
    var actionKey: LocalizedStringKey?
    var action: (() -> Void)?

    var body: some View {
        VStack(spacing: Space.m) {
            switch kind {
            case .loading:
                ProgressView()
                    .controlSize(.large)
                    .tint(Color.ds(.accent))
                Text("common.loading")
                    .textStyle(.subheadline)
                    .foregroundStyle(Color.ds(.textSecondary))
            case let .empty(symbol, titleKey, messageKey):
                IconBadge(systemName: symbol, color: .ds(.accent), size: .large)
                texts(title: titleKey, message: messageKey)
            case let .error(messageKey):
                IconBadge(systemName: "exclamationmark.arrow.triangle.2.circlepath", color: .ds(.categoryInsecurity), size: .large)
                texts(title: "state.error.title", message: messageKey)
            case .offline:
                IconBadge(systemName: "wifi.slash", color: .ds(.textSecondary), size: .large)
                texts(title: "state.offline.title", message: "state.offline.message")
            }
            if let actionKey, let action {
                DSButton(actionKey, kind: .secondary, fullWidth: false, action: action)
                    .padding(.top, Space.s)
            }
        }
        .multilineTextAlignment(.center)
        .padding(Space.xl)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .contain)
    }

    private func texts(title: LocalizedStringKey, message: LocalizedStringKey?) -> some View {
        VStack(spacing: Space.s) {
            Text(title)
                .textStyle(.headline)
                .foregroundStyle(Color.ds(.textPrimary))
            if let message {
                Text(message)
                    .textStyle(.subheadline)
                    .foregroundStyle(Color.ds(.textSecondary))
            }
        }
        .fixedSize(horizontal: false, vertical: true)
        .accessibilityElement(children: .combine)
    }
}

// MARK: - Step indicator

/// "Step 2 of 3" for the report flow. Segments animate as the user advances.
struct StepIndicator: View {
    let current: Int
    let total: Int

    var body: some View {
        HStack(spacing: Space.xs) {
            ForEach(1...total, id: \.self) { step in
                Capsule()
                    .fill(step <= current ? Color.ds(.accent) : Color.ds(.separator))
                    .frame(height: 4)
            }
        }
        .dsAnimation(Motion.standard, value: current)
        .accessibilityElement()
        .accessibilityLabel(Text("common.stepOf \(current) \(total)"))
    }
}

#Preview("Banners") {
    PreviewMatrix {
        VStack(spacing: Space.s) {
            Banner(kind: .serious, titleKey: "help.112.title", messageKey: "help.112.detail") {
                DSButton("help.112.title", systemImage: "phone.fill", kind: .destructive, fullWidth: false) {}
            }
            Banner(kind: .warning, titleKey: "textguard.physicalDescription")
            Banner(kind: .info, titleKey: "status.pending.title", messageKey: "status.pending.explanation")
        }
    }
}

#Preview("States") {
    PreviewMatrix {
        VStack(spacing: Space.s) {
            StateView(kind: .loading)
            StateView(kind: .empty(symbol: "map", titleKey: "status.resolved.title", messageKey: "status.resolved.explanation"))
            StateView(kind: .error(messageKey: "error.network"), actionKey: "common.retry") {}
            StateView(kind: .offline)
            StepIndicator(current: 2, total: 3)
        }
    }
}

#Preview("States — dark, AX5") {
    PreviewMatrix {
        VStack(spacing: Space.s) {
            StateView(kind: .error(messageKey: "error.network"), actionKey: "common.retry") {}
            Banner(kind: .serious, titleKey: "help.112.title", messageKey: "help.112.detail")
            StepIndicator(current: 1, total: 3)
        }
    }
    .previewAccessibilitySize()
    .preferredColorScheme(.dark)
}
