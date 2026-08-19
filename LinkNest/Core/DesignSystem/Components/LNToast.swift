//
//  LNToast.swift
//  Floating confirmation pill above the tab bar.
//

import SwiftUI

struct LNToast: View {
    var message: String

    var body: some View {
        Text(message)
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(LNColor.background)
            .padding(.horizontal, 18)
            .padding(.vertical, 10)
            .background(LNColor.primaryText, in: Capsule())
            .shadow(color: Color(hex: 0x0A0A14, alpha: 0.28), radius: 13, y: 10)
            .transition(.move(edge: .bottom).combined(with: .opacity))
            .accessibilityAddTraits(.updatesFrequently)
    }
}

/// Overlay host — attach once at the root.
struct ToastOverlay: ViewModifier {
    @Environment(AppState.self) private var appState

    func body(content: Content) -> some View {
        content.overlay(alignment: .bottom) {
            if let toast = appState.toast {
                LNToast(message: toast)
                    .padding(.bottom, 104)
                    .allowsHitTesting(false)
            }
        }
        .animation(LNAnimation.sheet, value: appState.toast)
    }
}
