import BruskBackend
import BruskCore
import SwiftUI

/// Sign-in by e-mailed one-time code only (spec §4.1). No password, no SMS.
struct SignInView: View {
    private enum Stage {
        case email
        case code
    }

    @Environment(AppEnvironment.self) private var environment
    @Environment(LanguageStore.self) private var language
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var stage: Stage = .email
    @State private var email = ""
    @State private var code = ""
    @State private var isWorking = false
    @State private var error: BackendError?
    @State private var resendAvailableAt = Date()
    @FocusState private var emailFocused: Bool

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: Space.l) {
                    IconBadge(systemName: stage == .email ? "envelope" : "envelope.open", color: .ds(.accent), size: .large)
                    VStack(alignment: .leading, spacing: Space.s) {
                        Text(stage == .email ? LocalizedStringKey("auth.email.title") : LocalizedStringKey("auth.code.title"))
                            .textStyle(.display)
                            .foregroundStyle(Color.ds(.textPrimary))
                            .accessibilityAddTraits(.isHeader)
                        if stage == .email {
                            Text("auth.email.message")
                                .textStyle(.body)
                                .foregroundStyle(Color.ds(.textSecondary))
                        } else {
                            Text("auth.code.sentTo \(email)")
                                .textStyle(.body)
                                .foregroundStyle(Color.ds(.textSecondary))
                        }
                    }
                    .fixedSize(horizontal: false, vertical: true)

                    switch stage {
                    case .email: emailForm
                    case .code: codeForm
                    }

                    if let error {
                        Banner(kind: .warning, titleKey: LocalizedStringKey(error.messageKey))
                    }

                    Label("auth.privacy", systemImage: "lock.shield")
                        .textStyle(.footnote)
                        .foregroundStyle(Color.ds(.textSecondary))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(Space.gutter)
                .dsAnimation(Motion.standard, value: stage == .code)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color.ds(.background))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button {
                        environment.session.cancelSignIn()
                        dismiss()
                    } label: {
                        Text("common.cancel")
                    }
                }
            }
        }
    }

    private var emailForm: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            TextField(text: $email, prompt: Text("walk.contact.placeholder")) {
                Text("auth.email.label")
            }
            .keyboardType(.emailAddress)
            .textContentType(.emailAddress)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.send)
            .focused($emailFocused)
            .onSubmit { Task { await sendCode() } }
            .textStyle(.body)
            .padding(Space.m)
            .frame(minHeight: ControlSize.button)
            .cardSurface(radius: Radius.medium)
            .onAppear { emailFocused = true }

            DSButton("auth.sendCode", systemImage: "paperplane", isLoading: isWorking) {
                Task { await sendCode() }
            }
            .disabled(!isValidEmail)
        }
    }

    private var codeForm: some View {
        VStack(alignment: .leading, spacing: Space.m) {
            OTPCodeField(code: $code, isError: error == .invalidCode)
                .disabled(isWorking)
                .onChange(of: code) { _, value in
                    if error == .invalidCode { error = nil }
                    if value.count == 6 { Task { await verify() } }
                }
            if isWorking {
                HStack(spacing: Space.s) {
                    ProgressView()
                    Text("auth.code.verifying")
                        .textStyle(.subheadline)
                        .foregroundStyle(Color.ds(.textSecondary))
                }
            }
            TimelineView(.periodic(from: .now, by: 1)) { context in
                let remaining = Int(resendAvailableAt.timeIntervalSince(context.date).rounded(.up))
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Space.s) { codeActions(remaining: remaining) }
                    VStack(alignment: .leading, spacing: Space.s) { codeActions(remaining: remaining) }
                }
            }
        }
    }

    @ViewBuilder
    private func codeActions(remaining: Int) -> some View {
        if remaining > 0 {
            DSButton("auth.code.resendIn \(remaining)", kind: .tertiary, fullWidth: false) {}
                .disabled(true)
        } else {
            DSButton("auth.code.resend", kind: .tertiary, fullWidth: false) {
                Task { await sendCode() }
            }
        }
        DSButton("auth.code.changeEmail", kind: .tertiary, fullWidth: false) {
            withMotion(Motion.standard, reduceMotion: reduceMotion) {
                stage = .email
                code = ""
                error = nil
            }
        }
    }

    private var isValidEmail: Bool {
        email.trimmingCharacters(in: .whitespaces).range(of: #"^[^@\s]+@[^@\s]+\.[^@\s]{2,}$"#, options: .regularExpression) != nil
    }

    private func sendCode() async {
        guard isValidEmail, !isWorking else { return }
        isWorking = true
        error = nil
        defer { isWorking = false }
        do {
            try await environment.backend.sendCode(to: email.trimmingCharacters(in: .whitespaces), language: language.resolved)
            resendAvailableAt = Date().addingTimeInterval(30)
            code = ""
            withMotion(Motion.standard, reduceMotion: reduceMotion) { stage = .code }
        } catch let failure as BackendError {
            error = failure
        } catch {
            self.error = .server(String(describing: error))
        }
    }

    private func verify() async {
        guard !isWorking else { return }
        isWorking = true
        defer { isWorking = false }
        do {
            let session = try await environment.backend.verifyCode(code, email: email.trimmingCharacters(in: .whitespaces))
            try? await environment.backend.setLanguage(language.resolved)
            environment.session.didSignIn(session)
        } catch let failure as BackendError {
            error = failure
            code = ""
        } catch {
            self.error = .server(String(describing: error))
        }
    }
}

#Preview("Sign in") {
    let environment = AppEnvironment.preview(signedIn: false)
    SignInView()
        .environment(environment)
        .environment(environment.language)
}

#Preview("Sign in — dark, Dutch, AX5") {
    let environment = AppEnvironment.preview(signedIn: false)
    SignInView()
        .environment(environment)
        .environment(environment.language)
        .environment(\.locale, Locale(identifier: "nl_BE"))
        .previewAccessibilitySize()
        .preferredColorScheme(.dark)
}
