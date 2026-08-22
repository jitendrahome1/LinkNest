//
//  SplashView.swift
//

import SwiftUI

struct SplashView: View {
    @Environment(AppState.self) private var appState
    @Environment(AppContainer.self) private var container
    @State private var appeared = false
    @State private var ring1 = false
    @State private var ring2 = false

    var body: some View {
        VStack(spacing: 0) {
            ZStack {
                pulseRing(active: ring1)
                pulseRing(active: ring2)

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
                    .animation(.spring(response: 0.7, dampingFraction: 0.7), value: appeared)
            }
            .frame(width: 220, height: 220)

            Text("LinkNest")
                .font(.system(size: 30, weight: .heavy))
                .kerning(-0.7)
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 0)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.15), value: appeared)

            Text(String(localized: "splash.tagline", defaultValue: "Save what matters."))
                .font(.system(size: 15))
                .foregroundStyle(LNColor.secondaryText)
                .padding(.top, 8)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.3), value: appeared)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .overlay(alignment: .bottom) {
            HStack(spacing: 6) {
                Circle().fill(LNColor.accent.opacity(0.9)).frame(width: 6, height: 6)
                Circle().fill(LNColor.accent.opacity(0.5)).frame(width: 6, height: 6)
                Circle().fill(LNColor.accent.opacity(0.25)).frame(width: 6, height: 6)
            }
            .opacity(appeared ? 1 : 0)
            .offset(y: appeared ? 0 : 20)
            .animation(.spring(response: 0.6, dampingFraction: 0.75).delay(0.45), value: appeared)
            .padding(.bottom, 54)
        }
        .background(LNColor.background)
        .contentShape(Rectangle())
        .onTapGesture { advance() }
        .task {
            withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { ring1 = true }
            Task {
                try? await Task.sleep(for: .seconds(0.6))
                withAnimation(.easeOut(duration: 2.2).repeatForever(autoreverses: false)) { ring2 = true }
            }
            appeared = true
            try? await Task.sleep(for: .seconds(2.4))
            advance()
        }
        .accessibilityLabel("LinkNest. Save what matters.")
    }

    private func pulseRing(active: Bool) -> some View {
        Circle()
            .stroke(LNColor.accent.opacity(0.35), lineWidth: 1)
            .frame(width: 220, height: 220)
            .scaleEffect(active ? 1.5 : 0.9)
            .opacity(active ? 0 : 0.5)
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
