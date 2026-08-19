//
//  LinkNestPDFBookmarkButton.swift
//  Bookmark toggle for the current page — same 38pt chip-icon language as
//  the reader's other bottom controls, accent-filled when active.
//

import SwiftUI

struct LinkNestPDFBookmarkButton: View {
    var isBookmarked: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Circle()
                .fill(LNColor.chip)
                .frame(width: 38, height: 38)
                .overlay {
                    Image(systemName: isBookmarked ? "bookmark.fill" : "bookmark")
                        .font(.system(size: 16, weight: .regular))
                        .foregroundStyle(isBookmarked ? LNColor.accent : LNColor.secondaryText)
                }
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isBookmarked)
        .accessibilityLabel(isBookmarked
            ? String(localized: "pdf.removeBookmark", defaultValue: "Remove bookmark")
            : String(localized: "pdf.addBookmark", defaultValue: "Bookmark this page"))
    }
}
