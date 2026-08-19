//
//  MainTabView.swift
//  Custom tab bar with the raised center Quick Save button,
//  matching the prototype (blur material, hairline top border,
//  accent glow on the plus).
//

import SwiftUI

struct MainTabView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    var body: some View {
        @Bindable var router = router
        ZStack(alignment: .bottom) {
            Group {
                switch router.tab {
                case .home:
                    NavigationStack(path: router.path(for: .home)) {
                        HomeView().navigationDestination(for: AppRoute.self) { destination(for: $0) }
                    }
                case .saved:
                    NavigationStack(path: router.path(for: .saved)) {
                        SavedView().navigationDestination(for: AppRoute.self) { destination(for: $0) }
                    }
                case .collections:
                    NavigationStack(path: router.path(for: .collections)) {
                        CollectionsView().navigationDestination(for: AppRoute.self) { destination(for: $0) }
                    }
                case .profile:
                    NavigationStack(path: router.path(for: .profile)) {
                        ProfileView().navigationDestination(for: AppRoute.self) { destination(for: $0) }
                    }
                }
            }

            if router.isTabBarVisible {
                LNTabBar()
                    .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .sheet(item: $router.sheet, onDismiss: { router.consumePendingRoute() }) { sheet in
            switch sheet {
            case .quickSave: QuickSaveSheet()
            case .filters: FilterSheet()
            case .sort: SortSheet()
            case .newCollection: NewCollectionSheet()
            case .itemMenu(let id): ItemMenuSheet(itemID: id)
            case .editItem(let id): EditItemSheet(itemID: id)
            }
        }
    }

    @ViewBuilder
    private func destination(for route: AppRoute) -> some View {
        switch route {
        case .contentDetail(let id): ContentDetailView(itemID: id)
        case .collectionDetail(let id): CollectionDetailView(collectionID: id)
        case .saveLink(let prefill): SaveLinkView(prefillURL: prefill)
        case .search: SearchView()
        }
    }
}

struct LNTabBar: View {
    @Environment(AppRouter.self) private var router

    var body: some View {
        HStack(alignment: .center, spacing: 0) {
            tabButton(.home)
            tabButton(.saved)
            plusButton
            tabButton(.collections)
            tabButton(.profile)
        }
        .padding(.horizontal, 10)
        .padding(.top, 10)
        .padding(.bottom, 24)
        .background {
            LNColor.tabBar
                .background(.ultraThinMaterial)
                .overlay(alignment: .top) {
                    Rectangle().fill(LNColor.separator).frame(height: 0.5)
                }
                .ignoresSafeArea(edges: .bottom)
        }
    }

    private func tabButton(_ tab: AppTab) -> some View {
        Button {
            router.switchTab(tab)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: tab.systemImage)
                    .font(.system(size: LNIconSize.tab, weight: .regular))
                Text(tab.label)
                    .font(LNFont.tabLabel)
            }
            .foregroundStyle(router.tab == tab ? LNColor.accent : LNColor.tertiaryText)
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tab.label)
        .accessibilityAddTraits(router.tab == tab ? .isSelected : [])
    }

    private var plusButton: some View {
        Button {
            router.sheet = .quickSave
        } label: {
            Circle()
                .fill(LNColor.accent)
                .frame(width: 52, height: 52)
                .overlay {
                    Image(systemName: "plus")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundStyle(.white)
                }
                .shadow(color: LNColor.accent.opacity(0.38), radius: 12, y: 6)
                .offset(y: -10)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity)
        .accessibilityLabel(String(localized: "a11y.quickSave", defaultValue: "Quick Save"))
    }
}
