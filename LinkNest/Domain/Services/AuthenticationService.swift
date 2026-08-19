//
//  AuthenticationService.swift
//  Protocol-first auth so Firebase / Supabase / a custom backend can be
//  swapped in without touching the UI. The mock validates and persists a
//  fake session in the Keychain.
//

import Foundation

struct AuthSession: Equatable, Sendable {
    var userName: String
    var email: String
}

enum AuthError: Error, LocalizedError {
    case invalidEmail
    case emptyPassword
    case weakPassword
    case passwordMismatch
    case emptyName

    var errorDescription: String? {
        switch self {
        case .invalidEmail: String(localized: "auth.invalidEmail", defaultValue: "Enter a valid email address")
        case .emptyPassword: String(localized: "auth.emptyPassword", defaultValue: "Enter your password")
        case .weakPassword: String(localized: "auth.weakPassword", defaultValue: "Password must be at least 8 characters")
        case .passwordMismatch: String(localized: "auth.mismatch", defaultValue: "Passwords do not match")
        case .emptyName: String(localized: "auth.emptyName", defaultValue: "Please enter your name")
        }
    }
}

@MainActor
protocol AuthenticationService: AnyObject {
    var currentSession: AuthSession? { get }
    func signIn(email: String, password: String) async throws -> AuthSession
    func signUp(name: String, email: String, password: String) async throws -> AuthSession
    func signInWithApple() async throws -> AuthSession
    func signInWithGoogle() async throws -> AuthSession
    func sendPasswordReset(email: String) async throws
    func signOut()
}

@MainActor
final class MockAuthenticationService: AuthenticationService {
    private let keychain: KeychainManager
    private(set) var currentSession: AuthSession?

    private static let emailKey = "session.email"
    private static let nameKey = "session.name"

    init(keychain: KeychainManager) {
        self.keychain = keychain
        if let email = keychain.get(Self.emailKey), let name = keychain.get(Self.nameKey) {
            currentSession = AuthSession(userName: name, email: email)
        }
    }

    static func validateEmail(_ email: String) -> Bool {
        email.wholeMatch(of: /\S+@\S+\.\S+/) != nil
    }

    func signIn(email: String, password: String) async throws -> AuthSession {
        guard Self.validateEmail(email) else { throw AuthError.invalidEmail }
        guard !password.isEmpty else { throw AuthError.emptyPassword }
        try await Task.sleep(for: .milliseconds(900))
        return persist(name: "Maya Chen", email: email)
    }

    func signUp(name: String, email: String, password: String) async throws -> AuthSession {
        guard !name.trimmingCharacters(in: .whitespaces).isEmpty else { throw AuthError.emptyName }
        guard Self.validateEmail(email) else { throw AuthError.invalidEmail }
        guard password.count >= 8 else { throw AuthError.weakPassword }
        try await Task.sleep(for: .milliseconds(900))
        return persist(name: name, email: email)
    }

    func signInWithApple() async throws -> AuthSession {
        try await Task.sleep(for: .milliseconds(600))
        return persist(name: "Maya Chen", email: "maya.chen@icloud.com")
    }

    func signInWithGoogle() async throws -> AuthSession {
        try await Task.sleep(for: .milliseconds(600))
        return persist(name: "Maya Chen", email: "maya.chen@gmail.com")
    }

    func sendPasswordReset(email: String) async throws {
        guard Self.validateEmail(email) else { throw AuthError.invalidEmail }
        try await Task.sleep(for: .milliseconds(600))
    }

    func signOut() {
        currentSession = nil
        keychain.remove(Self.emailKey)
        keychain.remove(Self.nameKey)
    }

    private func persist(name: String, email: String) -> AuthSession {
        keychain.set(email, for: Self.emailKey)
        keychain.set(name, for: Self.nameKey)
        let session = AuthSession(userName: name, email: email)
        currentSession = session
        return session
    }
}
