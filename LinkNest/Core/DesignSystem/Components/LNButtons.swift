//
//  LNButtons.swift
//

import SwiftUI

/// Full-width accent CTA ("Open Original", "Save Link", "Get Started").
struct LNPrimaryButton: View {
    var title: String
    var systemImage: String?
    var isLoading = false
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 7) {
                if isLoading { ProgressView().tint(.white) }
                Text(title)
                if let systemImage { Image(systemName: systemImage).font(.system(size: 14, weight: .semibold)) }
            }
            .font(LNFont.button)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity)
            .frame(height: 50)
            .background(LNColor.accent, in: RoundedRectangle(cornerRadius: LNRadius.button, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isLoading ? 0.6 : 1)
        .disabled(isLoading)
        .accessibilityLabel(title)
    }
}

/// Neutral full-width button ("Fetch Details").
struct LNSecondaryButton: View {
    var title: String
    var isEnabled = true
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 14.5, weight: .semibold))
                .foregroundStyle(LNColor.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 44)
                .background(LNColor.chip, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .opacity(isEnabled ? 1 : 0.5)
        .accessibilityLabel(title)
    }
}

/// 36pt circular chip button used in headers (back, filter, sort, favorite…).
struct LNIconButton: View {
    var systemImage: String
    var tint: Color = LNColor.secondaryText
    var background: Color = LNColor.chip
    var showsBadge = false
    var accessibilityLabel: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack(alignment: .topTrailing) {
                Circle()
                    .fill(background)
                    .frame(width: 36, height: 36)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: LNIconSize.action, weight: .medium))
                            .foregroundStyle(tint)
                    }
                if showsBadge {
                    Circle()
                        .fill(LNColor.accent)
                        .frame(width: 7, height: 7)
                        .offset(x: -5, y: 5)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
    }
}

#Preview("Buttons", traits: .sizeThatFitsLayout) {
    VStack(spacing: 16) {
        LNPrimaryButton(title: "Open Original", systemImage: "arrow.up.right") {}
        LNPrimaryButton(title: "Signing In…", isLoading: true) {}
        LNSecondaryButton(title: "Fetch Details") {}
        HStack {
            LNIconButton(systemImage: "chevron.left", tint: LNColor.primaryText, accessibilityLabel: "Back") {}
            LNIconButton(systemImage: "line.3.horizontal.decrease", showsBadge: true, accessibilityLabel: "Filters") {}
            LNIconButton(systemImage: "heart.fill", tint: LNColor.accent, accessibilityLabel: "Favorite") {}
        }
    }
    .padding(24)
    .background(LNColor.background)
}
