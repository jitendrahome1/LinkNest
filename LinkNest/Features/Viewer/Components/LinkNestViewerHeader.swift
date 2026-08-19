//
//  LinkNestViewerHeader.swift
//  Shared top bar for VideoPlayerView and PDFReaderView: back, optional
//  title/subtitle, optional favorite, optional trailing actions (search,
//  more). Same 36pt chip-button language as the rest of the app.
//

import SwiftUI

struct LinkNestViewerHeader: View {
    var title: String? = nil
    var subtitle: String? = nil
    var isFavorite: Bool? = nil
    var tint: Color = LNColor.primaryText
    /// True over the video's dark chrome (translucent dark chip, ignores app
    /// theme); false for the PDF reader's normal theme-aware chip background.
    var usesDarkChrome = false
    var onBack: () -> Void
    var onFavorite: (() -> Void)? = nil
    var onSearch: (() -> Void)? = nil
    var onMore: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 10) {
            chipButton(systemImage: "chevron.left", tint: tint,
                       label: String(localized: "a11y.back", defaultValue: "Back"),
                       action: onBack)

            if title != nil || subtitle != nil {
                VStack(alignment: .leading, spacing: 1) {
                    if let title {
                        Text(title)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(tint)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                    if let subtitle {
                        Text(subtitle)
                            .font(.system(size: 11))
                            .foregroundStyle(tint.opacity(0.55))
                            .lineLimit(1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                Spacer()
            }

            if let isFavorite, let onFavorite {
                chipButton(systemImage: isFavorite ? "heart.fill" : "heart",
                           tint: isFavorite ? LNColor.accent : tint,
                           label: String(localized: "a11y.favorite", defaultValue: "Favorite"),
                           action: onFavorite)
            }
            if let onSearch {
                chipButton(systemImage: "magnifyingglass", tint: tint,
                           label: String(localized: "a11y.search", defaultValue: "Search"),
                           action: onSearch)
            }
            if let onMore {
                chipButton(systemImage: "ellipsis", tint: tint,
                           label: String(localized: "a11y.moreActions", defaultValue: "More actions"),
                           action: onMore)
            }
        }
        .padding(.horizontal, 14)
    }

    private func chipButton(systemImage: String, tint: Color, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if usesDarkChrome {
                    Circle().fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                } else {
                    Circle().fill(LNColor.chip)
                }
            }
            .frame(width: 36, height: 36)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: LNIconSize.action, weight: .medium))
                    .foregroundStyle(tint)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
