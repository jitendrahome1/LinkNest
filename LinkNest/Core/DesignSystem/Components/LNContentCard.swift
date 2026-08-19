//
//  LNContentCard.swift
//  The three content-card layouts from the prototype:
//  large (horizontal rails), compact (lists) and grid (Saved grid mode).
//

import SwiftUI

struct LNContentCardLarge: View {
    let item: ContentItem
    var onOpen: () -> Void
    var onToggleFavorite: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ThumbnailView(hue: item.thumbnailHue, platform: item.platform,
                              duration: item.duration, thumbnailURL: item.thumbnailURL,
                              cornerRadius: 0, badgeScale: 1.2, contentType: item.contentType)
                    .frame(height: 128)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(LNFont.cardTitle)
                        .foregroundStyle(LNColor.primaryText)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    Text("\(item.platform.displayName) · \(item.creatorName)")
                        .font(LNFont.meta)
                        .foregroundStyle(LNColor.secondaryText)
                        .lineLimit(1)
                    HStack {
                        Text(item.savedAgo)
                            .font(LNFont.micro)
                            .foregroundStyle(LNColor.tertiaryText)
                        Spacer()
                        FavoriteButton(isFavorite: item.isFavorite, size: 17, action: onToggleFavorite)
                    }
                    .padding(.top, 3)
                }
                .padding(EdgeInsets(top: 11, leading: 13, bottom: 12, trailing: 13))
            }
            .frame(width: 248)
            .background(LNColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LNRadius.cardLarge, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CardShadow())
        .accessibilityLabel("\(item.title), \(item.platform.displayName), \(item.creatorName)")
    }
}

struct LNContentCardCompact: View {
    let item: ContentItem
    var showsMenu = true
    var onOpen: () -> Void
    var onToggleFavorite: () -> Void
    var onMenu: (() -> Void)? = nil

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 12) {
                ThumbnailView(hue: item.thumbnailHue, platform: item.platform,
                              duration: item.duration, thumbnailURL: item.thumbnailURL, contentType: item.contentType)
                    .frame(width: 94, height: 66)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13.5, weight: .semibold))
                        .foregroundStyle(LNColor.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(item.platform.displayName) · \(item.creatorName)")
                        .font(.system(size: 11.5))
                        .foregroundStyle(LNColor.secondaryText)
                        .lineLimit(1)
                    HStack(spacing: 8) {
                        Text(item.tags.map { "#\($0.name)" }.joined(separator: " "))
                            .font(.system(size: 10.5, weight: .medium))
                            .foregroundStyle(LNColor.accent)
                            .lineLimit(1)
                        Text(item.savedAgo)
                            .font(LNFont.micro)
                            .foregroundStyle(LNColor.tertiaryText)
                    }
                    .padding(.top, 1)
                }
                Spacer(minLength: 0)
                VStack {
                    if showsMenu, let onMenu {
                        Button(action: onMenu) {
                            Image(systemName: "ellipsis")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(LNColor.tertiaryText)
                                .frame(width: 24, height: 24)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(String(localized: "a11y.moreActions", defaultValue: "More actions"))
                        Spacer()
                    }
                    FavoriteButton(isFavorite: item.isFavorite, size: 16, action: onToggleFavorite)
                }
                .padding(.vertical, 2)
            }
            .padding(10)
            .background(LNColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CardShadow())
        .accessibilityLabel("\(item.title), \(item.platform.displayName), \(item.creatorName), \(item.savedAgo)")
    }
}

struct LNContentCardGrid: View {
    let item: ContentItem
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                ThumbnailView(hue: item.thumbnailHue, platform: item.platform,
                              duration: nil, thumbnailURL: item.thumbnailURL, cornerRadius: 0, contentType: item.contentType)
                    .frame(height: 96)
                VStack(alignment: .leading, spacing: 5) {
                    Text(item.title)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(LNColor.primaryText)
                        .lineLimit(2, reservesSpace: true)
                        .multilineTextAlignment(.leading)
                    Text(item.savedAgo)
                        .font(LNFont.micro)
                        .foregroundStyle(LNColor.tertiaryText)
                }
                .padding(EdgeInsets(top: 9, leading: 11, bottom: 11, trailing: 11))
            }
            .background(LNColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CardShadow())
        .accessibilityLabel(item.title)
    }
}

struct FavoriteButton: View {
    var isFavorite: Bool
    var size: CGFloat = 16
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .font(.system(size: size, weight: .medium))
                .foregroundStyle(isFavorite ? LNColor.accent : LNColor.tertiaryText)
                .contentTransition(.symbolEffect(.replace))
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .sensoryFeedback(.impact(weight: .light), trigger: isFavorite)
        .accessibilityLabel(isFavorite
            ? String(localized: "a11y.unfavorite", defaultValue: "Remove from Favorites")
            : String(localized: "a11y.favorite", defaultValue: "Add to Favorites"))
    }
}

struct CardShadow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: Color(hex: 0x141428, alpha: 0.05), radius: 3, y: 1)
    }
}
