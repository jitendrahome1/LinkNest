//
//  AuthView.swift
//  Sign In / Sign Up / Reset — card fields with inline validation,
//  Apple/Google buttons, exactly per the prototype.
//

import SwiftUI

struct AuthView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var vm: AuthViewModel?

    var body: some View {
        ScrollView {
            if let vm {
                AuthContent(vm: vm)
            }
        }
        .scrollBounceBehavior(.basedOnSize)
        .background(LNColor.background)
        .task {
            guard vm == nil else { return }
            let model = AuthViewModel(auth: container.authService)
            model.onAuthenticated = { session in
                router.resetToHome()
                appState.phase = .main
                appState.showToast(String(localized: "auth.welcome", defaultValue: "Welcome back, ")
                    + session.userName.components(separatedBy: " ").first!)
                Task { await container.syncService.syncNow() }
            }
            model.onSignedUp = { container.seedDefaultCollections() }
            model.onToast = { appState.showToast($0) }
            vm = model
        }
        .onReceive(NotificationCenter.default.publisher(for: .authModeRequest)) { note in
            if let raw = note.object as? String {
                vm?.switchMode(raw == "signup" ? .signUp : .signIn)
            }
        }
    }
}

private struct AuthContent: View {
    @Bindable var vm: AuthViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(LNColor.accent)
                .frame(width: 60, height: 60)
                .overlay {
                    Image(systemName: "link")
                        .font(.system(size: 26, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: LNColor.accent.opacity(0.3), radius: 14, y: 12)

            switch vm.mode {
            case .signIn: signIn
            case .signUp: signUp
            case .forgotPassword: forgot
            }
        }
        .padding(.horizontal, 26)
        .padding(.top, 32)
        .padding(.bottom, 40)
    }

    // MARK: Sign In

    private var signIn: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(String(localized: "auth.welcomeBack", defaultValue: "Welcome back"),
                   String(localized: "auth.signInSub", defaultValue: "Sign in to your LinkNest library."))

            Button { vm.continueWithApple() } label: {
                Text(String(localized: "auth.apple", defaultValue: "Continue with Apple"))
                    .font(.system(size: 15.5, weight: .semibold))
                    .foregroundStyle(LNColor.background)
                    .frame(maxWidth: .infinity)
                    .frame(height: 50)
                    .background(LNColor.primaryText, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            }
            .buttonStyle(.plain)
            .padding(.top, 24)

            Button { vm.continueWithGoogle() } label: {
                HStack(spacing: 8) {
                    Text("G").font(.system(size: 17, weight: .heavy)).foregroundStyle(Color(hex: 0x4285F4))
                    Text(String(localized: "auth.google", defaultValue: "Continue with Google"))
                        .font(.system(size: 15.5, weight: .semibold))
                        .foregroundStyle(LNColor.primaryText)
                }
                .frame(maxWidth: .infinity)
                .frame(height: 50)
                .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(LNColor.separator, lineWidth: 1)
                }
            }
            .buttonStyle(.plain)
            .padding(.top, 10)

            divider.padding(.vertical, 20)

            AuthField(placeholder: String(localized: "auth.email", defaultValue: "Email"),
                      text: $vm.email, error: vm.emailError, keyboard: .emailAddress)
            AuthField(placeholder: String(localized: "auth.password", defaultValue: "Password"),
                      text: $vm.password, error: vm.passwordError, isSecure: true)
                .padding(.top, 10)

            LNPrimaryButton(title: vm.isBusy
                ? String(localized: "auth.signingIn", defaultValue: "Signing In…")
                : String(localized: "auth.signInCta", defaultValue: "Sign In"),
                isLoading: vm.isBusy) { vm.signIn() }
                .padding(.top, 16)

            centered {
                Button(String(localized: "auth.forgot", defaultValue: "Forgot Password?")) { vm.switchMode(.forgotPassword) }
                    .font(.system(size: 13.5, weight: .medium))
                    .foregroundStyle(LNColor.accent)
                    .buttonStyle(.plain)
            }
            .padding(.top, 14)

            footer(prompt: String(localized: "auth.noAccount", defaultValue: "Don't have an account?"),
                   cta: String(localized: "auth.signUpCta", defaultValue: "Sign Up")) { vm.switchMode(.signUp) }
        }
    }

    // MARK: Sign Up

    private var signUp: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(String(localized: "auth.create", defaultValue: "Create your account"),
                   String(localized: "auth.createSub", defaultValue: "Start building your personal library."))

            AuthField(placeholder: String(localized: "auth.name", defaultValue: "Name"),
                      text: $vm.name, error: vm.nameError)
                .padding(.top, 24)
            AuthField(placeholder: String(localized: "auth.email", defaultValue: "Email"),
                      text: $vm.email, error: vm.emailError, keyboard: .emailAddress)
                .padding(.top, 10)
            AuthField(placeholder: String(localized: "auth.password8", defaultValue: "Password (8+ characters)"),
                      text: $vm.password, error: vm.passwordError, isSecure: true)
                .padding(.top, 10)
            AuthField(placeholder: String(localized: "auth.confirm", defaultValue: "Confirm password"),
                      text: $vm.confirmPassword, error: vm.confirmError, isSecure: true)
                .padding(.top, 10)

            LNPrimaryButton(title: vm.isBusy
                ? String(localized: "auth.creating", defaultValue: "Creating Account…")
                : String(localized: "auth.createCta", defaultValue: "Create Account"),
                isLoading: vm.isBusy) { vm.signUp() }
                .padding(.top, 16)

            footer(prompt: String(localized: "auth.hasAccount", defaultValue: "Already have an account?"),
                   cta: String(localized: "auth.signInCta", defaultValue: "Sign In")) { vm.switchMode(.signIn) }
        }
    }

    // MARK: Forgot

    private var forgot: some View {
        VStack(alignment: .leading, spacing: 0) {
            header(String(localized: "auth.reset", defaultValue: "Reset password"),
                   String(localized: "auth.resetSub", defaultValue: "Enter your email and we'll send you a reset link."))

            AuthField(placeholder: String(localized: "auth.email", defaultValue: "Email"),
                      text: $vm.email, error: vm.emailError, keyboard: .emailAddress)
                .padding(.top, 24)

            LNPrimaryButton(title: String(localized: "auth.sendReset", defaultValue: "Send Reset Link"),
                            isLoading: vm.isBusy) { vm.sendReset() }
                .padding(.top, 16)

            centered {
                Button(String(localized: "auth.backToSignIn", defaultValue: "Back to Sign In")) { vm.switchMode(.signIn) }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LNColor.accent)
                    .buttonStyle(.plain)
            }
            .padding(.top, 20)
        }
    }

    // MARK: Pieces

    private func header(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(title)
                .font(.system(size: 26, weight: .heavy))
                .kerning(-0.5)
                .foregroundStyle(LNColor.primaryText)
            Text(subtitle)
                .font(.system(size: 14.5))
                .foregroundStyle(LNColor.secondaryText)
        }
        .padding(.top, 22)
    }

    private var divider: some View {
        HStack(spacing: 12) {
            Rectangle().fill(LNColor.separator).frame(height: 0.5)
            Text(String(localized: "auth.or", defaultValue: "or"))
                .font(.system(size: 12))
                .foregroundStyle(LNColor.tertiaryText)
            Rectangle().fill(LNColor.separator).frame(height: 0.5)
        }
    }

    private func centered<V: View>(@ViewBuilder _ content: () -> V) -> some View {
        HStack { Spacer(); content(); Spacer() }
    }

    private func footer(prompt: String, cta: String, action: @escaping () -> Void) -> some View {
        centered {
            HStack(spacing: 4) {
                Text(prompt).foregroundStyle(LNColor.secondaryText)
                Button(cta, action: action)
                    .foregroundStyle(LNColor.accent)
                    .fontWeight(.semibold)
                    .buttonStyle(.plain)
            }
            .font(.system(size: 14))
        }
        .padding(.top, 26)
    }
}

private struct AuthField: View {
    var placeholder: String
    @Binding var text: String
    var error: String?
    var isSecure = false
    var keyboard: UIKeyboardType = .default

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                        .keyboardType(keyboard)
                        .textInputAutocapitalization(keyboard == .emailAddress ? .never : .words)
                        .autocorrectionDisabled(keyboard == .emailAddress)
                }
            }
            .font(LNFont.body)
            .foregroundStyle(LNColor.primaryText)
            .padding(.horizontal, 15)
            .frame(height: 50)
            .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(error == nil ? Color.clear : LNColor.destructive, lineWidth: 1.5)
            }
            .modifier(CardShadow())

            if let error {
                Text(error)
                    .font(.system(size: 12.5))
                    .foregroundStyle(LNColor.destructive)
                    .padding(.horizontal, 2)
            }
        }
        .animation(.easeOut(duration: 0.15), value: error)
        .accessibilityLabel(placeholder)
        .accessibilityHint(error ?? "")
    }
}
