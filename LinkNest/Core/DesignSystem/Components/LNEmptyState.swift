//
//  LNEmptyState.swift
//

import SwiftUI

struct LNEmptyState: View {
    var systemImage: String
    var title: String
    var message: String
    var ctaTitle: String?
    var ctaAction: (() -> Void)?

    var body: some View {
        VStack(spacing: 0) {
            Image(systemName: systemImage)
                .font(.system(size: LNIconSize.empty, weight: .light))
                .foregroundStyle(LNColor.tertiaryText)
            Text(title)
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 14)
            Text(message)
                .font(.system(size: 13))
                .foregroundStyle(LNColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(3)
                .padding(.top, 5)
            if let ctaTitle, let ctaAction {
                Button(action: ctaAction) {
                    Text(ctaTitle)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 18)
                        .frame(height: 40)
                        .background(LNColor.accent, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.top, 16)
            }
        }
        .padding(.horizontal, 40)
        .padding(.top, 56)
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
    }
}

#Preview("Empty states", traits: .sizeThatFitsLayout) {
    VStack {
        LNEmptyState(systemImage: "bookmark",
                     title: "Nothing here yet",
                     message: "Nothing matches this view. Try different filters, or save something new.",
                     ctaTitle: "Save Your First Link") {}
        LNEmptyState(systemImage: "magnifyingglass",
                     title: "No results",
                     message: "Check the spelling, or try a broader term like a tag or creator name.")
    }
    .background(LNColor.background)
}
