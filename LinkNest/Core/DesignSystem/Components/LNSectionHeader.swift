//
//  LNSectionHeader.swift
//

import SwiftUI

/// "Recently Saved   See All" — bold header row with optional accent action.
struct LNSectionHeader: View {
    var title: String
    var actionTitle: String?
    var action: (() -> Void)?

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(LNFont.sectionHeader)
                .foregroundStyle(LNColor.primaryText)
            Spacer()
            if let actionTitle, let action {
                Button(action: action) {
                    Text(actionTitle)
                        .font(LNFont.chip)
                        .foregroundStyle(LNColor.accent)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, LNSpacing.gutter)
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isHeader)
    }
}

/// Small uppercase label above cards ("MY NOTES", "COLLECTION").
struct LNSectionLabel: View {
    var text: String

    var body: some View {
        Text(text.uppercased())
            .font(LNFont.sectionLabel)
            .kerning(0.4)
            .foregroundStyle(LNColor.secondaryText)
            .accessibilityAddTraits(.isHeader)
    }
}
