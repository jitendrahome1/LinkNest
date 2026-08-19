//
//  AppState.swift
//  Session-level UI state: launch phase, theme, toasts.
//

import SwiftUI
import Observation

enum LaunchPhase: String {
    case splash, onboarding, auth, main
}

enum ThemeMode: String, CaseIterable, Identifiable {
    case system, light, dark
    var id: String { rawValue }
    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
    var label: String {
        switch self {
        case .system: String(localized: "appearance.system", defaultValue: "System")
        case .light: String(localized: "appearance.light", defaultValue: "Light")
        case .dark: String(localized: "appearance.dark", defaultValue: "Dark")
        }
    }
}

@Observable
@MainActor
final class AppState {
    var phase: LaunchPhase
    var toast: String?

    var themeMode: ThemeMode {
        didSet { UserDefaults.standard.set(themeMode.rawValue, forKey: Self.themeKey) }
    }

    private static let themeKey = "linknest.themeMode"
    private static let onboardedKey = "linknest.hasOnboarded"
    private var toastTask: Task<Void, Never>?

    var hasOnboarded: Bool {
        didSet { UserDefaults.standard.set(hasOnboarded, forKey: Self.onboardedKey) }
    }

    init() {
        themeMode = ThemeMode(rawValue: UserDefaults.standard.string(forKey: Self.themeKey) ?? "") ?? .system
        hasOnboarded = UserDefaults.standard.bool(forKey: Self.onboardedKey)
        phase = .splash
    }

    func advanceFromSplash(isSignedIn: Bool) {
        if isSignedIn { phase = .main }
        else if hasOnboarded { phase = .auth }
        else { phase = .onboarding }
    }

    func showToast(_ message: String) {
        toastTask?.cancel()
        toast = message
        toastTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else { return }
            self?.toast = nil
        }
    }
}
