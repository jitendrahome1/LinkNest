//
//  LinkNestViewerErrorView.swift
//  Shared error state for the video and PDF viewers: message, Retry, and
//  an optional secondary action (e.g. "Open Original" when a source can't
//  be played natively at all).
//

import SwiftUI

struct LinkNestViewerErrorView: View {
    var systemImage: String = "exclamationmark.triangle"
    var title: String
    var message: String
    var retryTitle: String? = nil
    var onRetry: (() -> Void)? = nil
    var secondaryTitle: String? = nil
    var onSecondary: (() -> Void)? = nil
    /// Video's dark chrome needs light text/icons; PDF sits on the normal theme.
    var onDarkChrome = false

    private var foreground: Color { onDarkChrome ? .white : LNColor.primaryText }
    private var secondaryForeground: Color { onDarkChrome ? .white.opacity(0.65) : LNColor.secondaryText }

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: systemImage)
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(secondaryForeground)
            VStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(foreground)
                Text(message)
                    .font(.system(size: 13))
                    .foregroundStyle(secondaryForeground)
                    .multilineTextAlignment(.center)
                    .lineSpacing(3)
            }
            .padding(.horizontal, 32)

            HStack(spacing: 10) {
                if let retryTitle, let onRetry {
                    Button(action: onRetry) {
                        Text(retryTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(LNColor.accent, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
                if let secondaryTitle, let onSecondary {
                    Button(action: onSecondary) {
                        Text(secondaryTitle)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(foreground)
                            .padding(.horizontal, 18)
                            .frame(height: 40)
                            .background(onDarkChrome ? Color.white.opacity(0.14) : LNColor.chip, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
