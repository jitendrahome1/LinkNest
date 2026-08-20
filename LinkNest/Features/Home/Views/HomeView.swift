//
//  HomeView.swift
//  Greeting · search · quick actions · stats · Recently Saved rail ·
//  Continue Exploring rail · Your Collections grid.
//

import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<ContentItem> { !$0.isArchived },
           sort: \ContentItem.createdAt, order: .reverse)
    private var items: [ContentItem]

    @Query(sort: \ContentCollection.sortIndex)
    private var collections: [ContentCollection]

    private var userName: String {
        container.authService.currentSession?.userName.components(separatedBy: " ").first ?? "Maya"
    }

    private var greeting: String {
        switch Calendar.current.component(.hour, from: .now) {
        case ..<12: String(localized: "home.morning", defaultValue: "Good morning")
        case ..<18: String(localized: "home.afternoon", defaultValue: "Good afternoon")
        default: String(localized: "home.evening", defaultValue: "Good evening")
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                headerRow
                LNSearchButton(placeholder: String(localized: "home.search", defaultValue: "Search your saved content")) {
                    router.push(.search)
                }
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 16)

                quickActions.padding(.top, 18)
                StatsCard(stats: [
                    (String(localized: "stat.saved", defaultValue: "Saved"), items.count),
                    (String(localized: "stat.favorites", defaultValue: "Favorites"), items.filter(\.isFavorite).count),
                    (String(localized: "stat.collections", defaultValue: "Collections"), collections.count),
                    (String(localized: "stat.watchLater", defaultValue: "Watch Later"), items.filter(\.isWatchLater).count)
                ])
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 20)

                if !items.isEmpty {
                    LNSectionHeader(title: String(localized: "home.recentlySaved", defaultValue: "Recently Saved"),
                                    actionTitle: String(localized: "home.seeAll", defaultValue: "See All")) {
                        router.switchTab(.saved)
                    }
                    .padding(.top, 24)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 12) {
                            ForEach(items.prefix(8)) { item in
                                LNContentCardLarge(item: item, onOpen: { open(item) },
                                                   onToggleFavorite: { toggleFavorite(item) })
                            }
                        }
                        .padding(.horizontal, LNSpacing.gutter)
                        .padding(.vertical, 4)
                    }
                    .padding(.top, 6)
                }

                if !watchLaterItems.isEmpty {
                    LNSectionHeader(title: String(localized: "home.continueExploring", defaultValue: "Continue Exploring"),
                                    actionTitle: String(localized: "home.seeAll", defaultValue: "See All")) {
                        router.switchTab(.saved)
                    }
                    .padding(.top, 14)
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 10) {
                            ForEach(watchLaterItems) { item in
                                ExploreCard(item: item) { open(item) }
                            }
                        }
                        .padding(.horizontal, LNSpacing.gutter)
                        .padding(.vertical, 4)
                    }
                    .padding(.top, 6)
                }

                LNSectionHeader(title: String(localized: "home.yourCollections", defaultValue: "Your Collections"),
                                actionTitle: String(localized: "home.seeAll", defaultValue: "See All")) {
                    router.switchTab(.collections)
                }
                .padding(.top, 14)
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(collections.prefix(4)) { collection in
                        LNCollectionCard(collection: collection) {
                            router.push(.collectionDetail(collection.id))
                        }
                    }
                }
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 6)
            }
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .background(LNColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var watchLaterItems: [ContentItem] { items.filter { $0.isWatchLater && !$0.isCompleted } }

    private var headerRow: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text("\(greeting), \(userName)")
                    .font(LNFont.greeting)
                    .kerning(-0.4)
                    .foregroundStyle(LNColor.primaryText)
                Text(String(localized: "home.subtitle", defaultValue: "What would you like to revisit?"))
                    .font(LNFont.callout)
                    .foregroundStyle(LNColor.secondaryText)
            }
            Spacer()
            LNIconButton(systemImage: "bell", showsBadge: true,
                         accessibilityLabel: String(localized: "a11y.notifications", defaultValue: "Notifications")) {
                appState.showToast(String(localized: "toast.nextRound", defaultValue: "Notifications come in the next round"))
            }
        }
        .padding(.horizontal, LNSpacing.gutter)
    }

    private var quickActions: some View {
        HStack(spacing: 8) {
            QuickAction(systemImage: "link", label: String(localized: "qa.saveLink", defaultValue: "Save Link")) {
                router.push(.saveLink(prefill: nil))
            }
            QuickAction(systemImage: "heart", label: String(localized: "qa.favorites", defaultValue: "Favorites")) {
                container.savedFilterRequest = .favorites
                router.switchTab(.saved)
            }
            QuickAction(systemImage: "play.circle", label: String(localized: "qa.watchLater", defaultValue: "Watch Later")) {
                container.savedFilterRequest = .watchLater
                router.switchTab(.saved)
            }
            QuickAction(systemImage: "clock", label: String(localized: "qa.recent", defaultValue: "Recent")) {
                container.savedFilterRequest = .recent
                router.switchTab(.saved)
            }
        }
        .padding(.horizontal, LNSpacing.gutter)
    }

    private func open(_ item: ContentItem) {
        container.contentRepository.markViewed(item)
        router.push(.viewer(for: item))
    }

    private func toggleFavorite(_ item: ContentItem) {
        item.isFavorite.toggle()
        container.contentRepository.save()
        appState.showToast(item.isFavorite
            ? String(localized: "toast.favorited", defaultValue: "Added to Favorites")
            : String(localized: "toast.unfavorited", defaultValue: "Removed from Favorites"))
    }
}

private struct QuickAction: View {
    var systemImage: String
    var label: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 7) {
                RoundedRectangle(cornerRadius: 17, style: .continuous)
                    .fill(LNColor.accentSoft)
                    .frame(width: 50, height: 50)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: LNIconSize.quickAction, weight: .medium))
                            .foregroundStyle(LNColor.accent)
                    }
                Text(label)
                    .font(LNFont.caption)
                    .foregroundStyle(LNColor.secondaryText)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

struct StatsCard: View {
    var stats: [(String, Int)]

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(stats.enumerated()), id: \.offset) { index, stat in
                VStack(spacing: 2) {
                    Text("\(stat.1)")
                        .font(.system(size: 20, weight: .bold))
                        .foregroundStyle(LNColor.primaryText)
                        .contentTransition(.numericText())
                    Text(stat.0)
                        .font(.system(size: 11))
                        .foregroundStyle(LNColor.secondaryText)
                }
                .frame(maxWidth: .infinity)
                .overlay(alignment: .leading) {
                    if index > 0 {
                        Rectangle().fill(LNColor.separator).frame(width: 1, height: 34)
                    }
                }
                .accessibilityElement(children: .combine)
            }
        }
        .padding(.vertical, 15)
        .background(LNColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LNRadius.statCard, style: .continuous))
        .modifier(CardShadow())
    }
}

private struct ExploreCard: View {
    let item: ContentItem
    var onOpen: () -> Void

    var body: some View {
        Button(action: onOpen) {
            HStack(spacing: 10) {
                ThumbnailView(hue: item.thumbnailHue, platform: item.platform,
                              duration: nil, thumbnailURL: item.thumbnailURL, cornerRadius: 9, badgeScale: 0.9, contentType: item.contentType)
                    .frame(width: 64, height: 48)
                VStack(alignment: .leading, spacing: 3) {
                    Text(item.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(LNColor.primaryText)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(item.platform.displayName) · \(item.duration ?? item.contentType.displayName)")
                        .font(.system(size: 11))
                        .foregroundStyle(LNColor.secondaryText)
                }
                Spacer(minLength: 0)
            }
            .padding(10)
            .frame(width: 236)
            .background(LNColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CardShadow())
        .accessibilityLabel(item.title)
    }
}
