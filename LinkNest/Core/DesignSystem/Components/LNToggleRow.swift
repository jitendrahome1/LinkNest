//
//  LNToggleRow.swift
//  Card-grouped rows: toggle, navigation and detail variants.
//

import SwiftUI

struct LNToggleRow: View {
    var title: String
    @Binding var isOn: Bool

    var body: some View {
        HStack {
            Text(title)
                .font(.system(size: 14.5))
                .foregroundStyle(LNColor.primaryText)
            Spacer()
            Toggle(title, isOn: $isOn)
                .labelsHidden()
                .tint(LNColor.accent)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .frame(minHeight: 48)
    }
}

struct LNDetailRow: View {
    var label: String
    var value: String

    var body: some View {
        HStack {
            Text(label)
                .font(LNFont.callout)
                .foregroundStyle(LNColor.secondaryText)
            Spacer()
            Text(value)
                .font(LNFont.callout)
                .foregroundStyle(LNColor.primaryText)
        }
        .padding(.horizontal, 14)
        .frame(minHeight: 46)
        .accessibilityElement(children: .combine)
    }
}

/// White grouped card wrapping rows with hairline separators.
struct LNGroupCard<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        VStack(spacing: 0) { content }
            .background(LNColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
            .modifier(CardShadow())
    }
}

struct LNRowSeparator: View {
    var body: some View {
        Rectangle()
            .fill(LNColor.separator)
            .frame(height: 0.5)
            .padding(.leading, 14)
    }
}
