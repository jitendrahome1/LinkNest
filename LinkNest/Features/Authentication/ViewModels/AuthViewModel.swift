//
//  AuthViewModel.swift
//

import Foundation
import Observation

enum AuthMode { case signIn, signUp, forgotPassword }

@Observable
@MainActor
final class AuthViewModel {
    var mode: AuthMode = .signIn
    var name = ""
    var email = ""
    var password = ""
    var confirmPassword = ""
    var isBusy = false

    var nameError: String?
    var emailError: String?
    var passwordError: String?
    var confirmError: String?

    private let auth: any AuthenticationService
    var onAuthenticated: ((AuthSession) -> Void)?
    /// Fires only for a brand-new account, after `onAuthenticated` — never on sign-in.
    var onSignedUp: (() -> Void)?
    var onToast: ((String) -> Void)?

    init(auth: any AuthenticationService) {
        self.auth = auth
    }

    func switchMode(_ newMode: AuthMode) {
        mode = newMode
        clearErrors()
    }

    func clearErrors() {
        nameError = nil; emailError = nil; passwordError = nil; confirmError = nil
    }

    func signIn() {
        clearErrors()
        guard MockAuthenticationService.validateEmail(email) else {
            emailError = AuthError.invalidEmail.errorDescription; return
        }
        guard !password.isEmpty else {
            passwordError = AuthError.emptyPassword.errorDescription; return
        }
        run { try await self.auth.signIn(email: self.email, password: self.password) }
    }

    func signUp() {
        clearErrors()
        var hasError = false
        if name.trimmingCharacters(in: .whitespaces).isEmpty {
            nameError = AuthError.emptyName.errorDescription; hasError = true
        }
        if !MockAuthenticationService.validateEmail(email) {
            emailError = AuthError.invalidEmail.errorDescription; hasError = true
        }
        if password.count < 8 {
            passwordError = AuthError.weakPassword.errorDescription; hasError = true
        }
        if confirmPassword != password {
            confirmError = AuthError.passwordMismatch.errorDescription; hasError = true
        }
        guard !hasError else { return }
        run(isSignUp: true) { try await self.auth.signUp(name: self.name, email: self.email, password: self.password) }
    }

    func continueWithApple() { run { try await self.auth.signInWithApple() } }
    func continueWithGoogle() { run { try await self.auth.signInWithGoogle() } }

    func sendReset() {
        clearErrors()
        guard MockAuthenticationService.validateEmail(email) else {
            emailError = AuthError.invalidEmail.errorDescription; return
        }
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                try await auth.sendPasswordReset(email: email)
                mode = .signIn
                onToast?(String(localized: "auth.resetSent", defaultValue: "Reset link sent — check your inbox"))
            } catch {
                emailError = error.localizedDescription
            }
        }
    }

    private func run(isSignUp: Bool = false, _ operation: @escaping () async throws -> AuthSession) {
        isBusy = true
        Task {
            defer { isBusy = false }
            do {
                let session = try await operation()
                onAuthenticated?(session)
                if isSignUp { onSignedUp?() }
            } catch let error as AuthError {
                switch error {
                case .invalidEmail: emailError = error.errorDescription
                case .emptyPassword, .weakPassword: passwordError = error.errorDescription
                case .passwordMismatch: confirmError = error.errorDescription
                case .emptyName: nameError = error.errorDescription
                case .confirmationRequired, .providerNotConfigured: onToast?(error.errorDescription ?? "")
                }
            } catch {
                emailError = error.localizedDescription
            }
        }
    }
}
