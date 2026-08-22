//
//  SavedView.swift
//  Large title + filter/sort/layout controls · search · segments ·
//  list or grid · empty state. Swipe actions + context menus on rows.
//

import SwiftUI
import SwiftData

struct SavedView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @Query(filter: #Predicate<ContentItem> { !$0.isArchived },
           sort: \ContentItem.createdAt, order: .reverse)
    private var allItems: [ContentItem]

    @State private var vm: SavedViewModel?

    var body: some View {
        // ZStack keeps real content on screen while vm is nil — .task never
        // fires on EmptyView, so a bare `if let` would stay blank forever.
        ZStack {
            LNColor.background.ignoresSafeArea()
            if let vm {
                SavedContent(vm: vm, allItems: allItems)
            }
        }
        .task {
            if vm == nil { vm = SavedViewModel(filterContent: container.filterContent) }
            vm?.apply(container.savedFilterRequest)
            container.savedFilterRequest = nil
        }
    }
}

private struct SavedContent: View {
    @Bindable var vm: SavedViewModel
    var allItems: [ContentItem]

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    private var items: [ContentItem] { vm.items(from: allItems) }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                header
                LNSearchBar(placeholder: String(localized: "saved.search", defaultValue: "Search saved"),
                            text: $vm.filter.query)
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 14)
                LNSegmentedControl(selection: $vm.filter.segment)
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 12)

                if items.isEmpty {
                    LNEmptyState(systemImage: "bookmark",
                                 title: String(localized: "saved.emptyTitle", defaultValue: "Nothing here yet"),
                                 message: String(localized: "saved.emptyBody", defaultValue: "Nothing matches this view. Try different filters, or save something new."),
                                 ctaTitle: String(localized: "saved.emptyCta", defaultValue: "Save Your First Link")) {
                        router.push(.saveLink(prefill: nil))
                    }
                } else if vm.isGrid {
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                        ForEach(items) { item in
                            LNContentCardGrid(item: item) { open(item) }
                                .modifier(ItemContextMenu(item: item))
                        }
                    }
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 12)
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(items) { item in
                            LNContentCardCompact(item: item,
                                                 onOpen: { open(item) },
                                                 onToggleFavorite: { toggleFavorite(item) },
                                                 onMenu: { router.sheet = .itemMenu(item.id) })
                                .modifier(ItemContextMenu(item: item))
                        }
                    }
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 12)
                }
            }
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .background(LNColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .animation(.easeOut(duration: 0.2), value: vm.isGrid)
    }

    private var header: some View {
        HStack {
            Text(String(localized: "saved.title", defaultValue: "Saved"))
                .font(LNFont.screenTitle)
                .kerning(-0.5)
                .foregroundStyle(LNColor.primaryText)
            Spacer()
            HStack(spacing: 8) {
                LNIconButton(systemImage: "line.3.horizontal.decrease",
                             showsBadge: vm.filter.hasActiveFilters,
                             accessibilityLabel: String(localized: "a11y.filters", defaultValue: "Filters")) {
                    container.savedViewModel = vm
                    router.sheet = .filters
                }
                LNIconButton(systemImage: "arrow.up.arrow.down",
                             accessibilityLabel: String(localized: "a11y.sort", defaultValue: "Sort")) {
                    container.savedViewModel = vm
                    router.sheet = .sort
                }
                LNIconButton(systemImage: vm.isGrid ? "list.bullet" : "square.grid.2x2",
                             accessibilityLabel: String(localized: "a11y.layout", defaultValue: "Toggle layout")) {
                    vm.isGrid.toggle()
                }
            }
        }
        .padding(.horizontal, LNSpacing.gutter)
    }

    private func open(_ item: ContentItem) {
        // Push first — markViewed's SwiftData save is synchronous disk I/O,
        // and running it before the push made every tap block the start of
        // the navigation transition, showing up as a stutter before it moved.
        router.push(.viewer(for: item))
        Task { @MainActor in
            container.contentRepository.markViewed(item)
        }
    }

    private func toggleFavorite(_ item: ContentItem) {
        item.isFavorite.toggle()
        container.contentRepository.save()
        appState.showToast(item.isFavorite
            ? String(localized: "toast.favorited", defaultValue: "Added to Favorites")
            : String(localized: "toast.unfavorited", defaultValue: "Removed from Favorites"))
    }
}

/// Native context menu with the prototype's item actions.
struct ItemContextMenu: ViewModifier {
    let item: ContentItem
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                router.push(.viewer(for: item))
                Task { @MainActor in
                    container.contentRepository.markViewed(item)
                }
            } label: { Label(String(localized: "menu.open", defaultValue: "Open"), systemImage: "arrow.up.right.square") }

            Button {
                item.isFavorite.toggle()
                container.contentRepository.save()
            } label: {
                Label(item.isFavorite
                    ? String(localized: "menu.unfavorite", defaultValue: "Remove from Favorites")
                    : String(localized: "menu.favorite", defaultValue: "Add to Favorites"),
                    systemImage: item.isFavorite ? "heart.slash" : "heart")
            }

            Button {
                item.isWatchLater.toggle()
                container.contentRepository.save()
            } label: {
                Label(item.isWatchLater
                    ? String(localized: "menu.removeWatchLater", defaultValue: "Remove from Watch Later")
                    : String(localized: "menu.watchLater", defaultValue: "Add to Watch Later"),
                    systemImage: "play.circle")
            }

            Button {
                container.deleteContent.archive(item)
                appState.showToast(String(localized: "toast.archived", defaultValue: "Archived"))
            } label: { Label(String(localized: "menu.archive", defaultValue: "Archive"), systemImage: "archivebox") }

            Button(role: .destructive) {
                container.deleteContent.delete(item)
                appState.showToast(String(localized: "toast.deleted", defaultValue: "Moved to Recently Deleted"))
            } label: { Label(String(localized: "menu.delete", defaultValue: "Delete"), systemImage: "trash") }
        }
    }
}
