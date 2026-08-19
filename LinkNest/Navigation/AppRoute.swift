//
//  AppRoute.swift
//  Typed push destinations. Hashable so they drive NavigationStack paths
//  and can be reconstructed from deep links.
//

import Foundation

enum AppRoute: Hashable {
    case contentDetail(UUID)
    case collectionDetail(UUID)
    case saveLink(prefill: String?)
    case search
}

enum AppTab: String, CaseIterable, Identifiable {
    case home, saved, collections, profile
    var id: String { rawValue }

    var label: String {
        switch self {
        case .home: String(localized: "tab.home", defaultValue: "Home")
        case .saved: String(localized: "tab.saved", defaultValue: "Saved")
        case .collections: String(localized: "tab.collections", defaultValue: "Collections")
        case .profile: String(localized: "tab.profile", defaultValue: "Profile")
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .saved: "bookmark"
        case .collections: "folder"
        case .profile: "person.crop.circle"
        }
    }
}
