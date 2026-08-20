//
//  SupabaseAuthenticationService.swift
//  Real AuthenticationService backed by Supabase Auth (email/password).
//  Apple/Google buttons stay wired in the UI but throw
//  .providerNotConfigured until those providers are enabled in the
//  Supabase dashboard and given native implementations.
//

import Foundation
import Supabase

@MainActor
final class SupabaseAuthenticationService: AuthenticationService {
    private let client = SupabaseClientProvider.shared
    private(set) var currentSession: AuthSession?
    private var authStateTask: Task<Void, Never>?

    init() {
        currentSession = Self.mapSession(client.auth.currentSession)
        authStateTask = Task { [weak self] in
            guard let self else { return }
            for await (event, session) in client.auth.authStateChanges {
                switch event {
                case .initialSession, .signedIn, .tokenRefreshed, .userUpdated:
                    self.currentSession = Self.mapSession(session)
                case .signedOut:
                    self.currentSession = nil
                default:
                    break
                }
            }
        }
    }

    deinit {
        authStateTask?.cancel()
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard Self.validateEmail(email) else { throw AuthError.invalidEmail }
        guard !password.isEmpty else { throw AuthError.emptyPassword }
        let session = try await client.auth.signIn(email: email, password: password)
        let mapped = Self.mapSession(session)!
        currentSession = mapped
        return mapped
    }

    func signUp(name: String, email: String, password: String) async throws -> AuthSession {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { throw AuthError.emptyName }
        guard Self.validateEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 8 else { throw AuthError.weakPassword }
        let response = try await client.auth.signUp(email: email, password: password, data: ["name": .string(name)])
        guard let session = response.session else {
            // Email confirmation is required by the project's Auth settings.
            throw AuthError.confirmationRequired
        }
        let mapped = Self.mapSession(session)!
        currentSession = mapped
        return mapped
    }

    func signInWithApple() async throws -> AuthSession {
        throw AuthError.providerNotConfigured
    }

    func signInWithGoogle() async throws -> AuthSession {
        throw AuthError.providerNotConfigured
    }

    func sendPasswordReset(email: String) async throws {
        guard Self.validateEmail(email) else { throw AuthError.invalidEmail }
        try await client.auth.resetPasswordForEmail(email)
    }

    func signOut() {
        currentSession = nil
        Task { try? await client.auth.signOut() }
    }

    static func validateEmail(_ email: String) -> Bool {
        email.wholeMatch(of: /\S+@\S+\.\S+/) != nil
    }

    private static func mapSession(_ session: Session?) -> AuthSession? {
        guard let session else { return nil }
        let user = session.user
        var name = user.email?.components(separatedBy: "@").first ?? "LinkNest"
        if let raw = user.userMetadata["name"], case .string(let value) = raw, !value.isEmpty {
            name = value
        }
        return AuthSession(userName: name, email: user.email ?? "")
    }
}
