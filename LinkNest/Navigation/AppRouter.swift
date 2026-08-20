//
//  AppRouter.swift
//  Centralized navigation: one path per tab, plus the active sheet.
//

import SwiftUI
import Observation

@Observable
@MainActor
final class AppRouter {
    var tab: AppTab = .home
    var sheet: SheetRoute?
    /// Route to push once the active sheet finishes dismissing — pushing
    /// mid-dismissal can be dropped by NavigationStack.
    var pendingRoute: AppRoute?

    func dismissSheetThenPush(_ route: AppRoute) {
        pendingRoute = route
        sheet = nil
    }

    func consumePendingRoute() {
        guard let route = pendingRoute else { return }
        pendingRoute = nil
        push(route)
    }

    var homePath: [AppRoute] = []
    var savedPath: [AppRoute] = []
    var collectionsPath: [AppRoute] = []
    var profilePath: [AppRoute] = []

    func path(for tab: AppTab) -> Binding<[AppRoute]> {
        switch tab {
        case .home: Binding(get: { self.homePath }, set: { self.homePath = $0 })
        case .saved: Binding(get: { self.savedPath }, set: { self.savedPath = $0 })
        case .collections: Binding(get: { self.collectionsPath }, set: { self.collectionsPath = $0 })
        case .profile: Binding(get: { self.profilePath }, set: { self.profilePath = $0 })
        }
    }

    func push(_ route: AppRoute) {
        sheet = nil
        switch tab {
        case .home: homePath.append(route)
        case .saved: savedPath.append(route)
        case .collections: collectionsPath.append(route)
        case .profile: profilePath.append(route)
        }
    }

    func pop() {
        switch tab {
        case .home: if !homePath.isEmpty { homePath.removeLast() }
        case .saved: if !savedPath.isEmpty { savedPath.removeLast() }
        case .collections: if !collectionsPath.isEmpty { collectionsPath.removeLast() }
        case .profile: if !profilePath.isEmpty { profilePath.removeLast() }
        }
    }

    func switchTab(_ newTab: AppTab) {
        sheet = nil
        tab = newTab
    }

    /// Called on sign-out / sign-in so a new session always lands on
    /// Home, instead of wherever the last session's tab/nav stack was.
    func resetToHome() {
        sheet = nil
        pendingRoute = nil
        tab = .home
        homePath = []
        savedPath = []
        collectionsPath = []
        profilePath = []
    }

    /// The tab bar hides on pushed screens, matching the prototype.
    var isTabBarVisible: Bool {
        switch tab {
        case .home: homePath.isEmpty
        case .saved: savedPath.isEmpty
        case .collections: collectionsPath.isEmpty
        case .profile: profilePath.isEmpty
        }
    }
}
