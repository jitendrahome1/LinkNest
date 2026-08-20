//
//  SplashView.swift
//

import SwiftUI

struct SplashView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppContainer.self) private var container
    @State private var appeared = false

    var body: some View {
        VStack(spacing: 0) {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(LNColor.accent)
                .frame(width: 98, height: 98)
                .overlay {
                    Image(systemName: "link")
                        .font(.system(size: 42, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: LNColor.accent.opacity(0.35), radius: 22, y: 20)
                .scaleEffect(appeared ? 1 : 0.8)
                .opacity(appeared ? 1 : 0)

            Text("LinkNest")
                .font(.system(size: 30, weight: .heavy))
                .kerning(-0.7)
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 24)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)

            Text(String(localized: "splash.tagline", defaultValue: "Save what matters."))
                .font(.system(size: 15))
                .foregroundStyle(LNColor.secondaryText)
                .padding(.top, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(LNColor.background)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .task {
            withAnimation(.spring(response: 0.7, dampingFraction: 0.7)) { appeared = true }
            try? await Task.sleep(for: .seconds(2.4))
            advance()
        }
        .accessibilityLabel("LinkNest. Save what matters.")
    }

    private func advance() {
        guard appState.phase == .splash else { return }
        let isSignedIn = container.authService.currentSession != nil
        if isSignedIn {
            Task { await container.syncService.syncNow() }
        }
        appState.advanceFromSplash(isSignedIn: isSignedIn)
    }
}
