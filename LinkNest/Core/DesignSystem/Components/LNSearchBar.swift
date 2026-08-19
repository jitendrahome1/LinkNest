//
//  LNSearchBar.swift
//

import SwiftUI

/// Rounded chip-background search field (42pt tappable variant on Home,
/// 40pt editable variant on Saved/Search/Collection Detail).
struct LNSearchBar: View {
    var placeholder: String
    @Binding var text: String
    var isFocusedOnAppear = false

    @FocusState private var focused: Bool

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LNColor.tertiaryText)
            TextField(placeholder, text: $text)
                .font(LNFont.body)
                .foregroundStyle(LNColor.primaryText)
                .focused($focused)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
        }
        .padding(.horizontal, 12)
        .frame(height: 40)
        .background(LNColor.chip, in: RoundedRectangle(cornerRadius: LNRadius.field, style: .continuous))
        .onAppear { if isFocusedOnAppear { focused = true } }
        .accessibilityLabel(placeholder)
    }
}

/// Non-editable search affordance (Home) — navigates on tap.
struct LNSearchButton: View {
    var placeholder: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 15, weight: .semibold))
                Text(placeholder)
                    .font(LNFont.body)
                Spacer(minLength: 0)
            }
            .foregroundStyle(LNColor.tertiaryText)
            .padding(.horizontal, 13)
            .frame(height: 42)
            .background(LNColor.chip, in: RoundedRectangle(cornerRadius: 13, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(placeholder)
        .accessibilityHint(String(localized: "a11y.opensSearch", defaultValue: "Opens search"))
    }
}
