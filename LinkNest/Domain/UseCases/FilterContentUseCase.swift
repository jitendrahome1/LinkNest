//
//  FilterContentUseCase.swift
//  The Saved screen's segment + filter sheet + sort menu, as one pure function.
//

import Foundation

enum ContentSegment: String, CaseIterable, Identifiable {
    case all = "All", videos = "Videos", articles = "Articles", posts = "Posts"
    var id: String { rawValue }

    var contentType: ContentType? {
        switch self {
        case .all: nil
        case .videos: .video
        case .articles: .article
        case .posts: .post
        }
    }
}

enum SortOption: String, CaseIterable, Identifiable {
    case recentlySaved, oldest, aToZ, zToA, recentlyViewed
    var id: String { rawValue }

    var label: String {
        switch self {
        case .recentlySaved: String(localized: "sort.recent", defaultValue: "Recently Saved")
        case .oldest: String(localized: "sort.oldest", defaultValue: "Oldest")
        case .aToZ: "A – Z"
        case .zToA: "Z – A"
        case .recentlyViewed: String(localized: "sort.viewed", defaultValue: "Recently Viewed")
        }
    }
}

struct ContentFilter: Equatable {
    var segment: ContentSegment = .all
    var query: String = ""
    var platforms: Set<ContentPlatform> = []
    var types: Set<ContentType> = []
    var favoritesOnly = false
    var watchLaterOnly = false
    var sort: SortOption = .recentlySaved

    var hasActiveFilters: Bool {
        !platforms.isEmpty || !types.isEmpty || favoritesOnly || watchLaterOnly
    }

    mutating func reset() {
        platforms = []
        types = []
        favoritesOnly = false
        watchLaterOnly = false
    }
}

struct FilterContentUseCase {
    func callAsFunction(_ items: [ContentItem], filter: ContentFilter) -> [ContentItem] {
        var result = items

        if let type = filter.segment.contentType {
            result = result.filter { $0.contentType == type }
        }
        let q = filter.query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            result = result.filter { item in
                item.title.lowercased().contains(q)
                    || item.creatorName.lowercased().contains(q)
                    || item.tags.contains { $0.name.lowercased().contains(q) }
            }
        }
        if !filter.platforms.isEmpty {
            result = result.filter { filter.platforms.contains($0.platform) }
        }
        if !filter.types.isEmpty {
            result = result.filter { filter.types.contains($0.contentType) }
        }
        if filter.favoritesOnly { result = result.filter(\.isFavorite) }
        if filter.watchLaterOnly { result = result.filter(\.isWatchLater) }

        switch filter.sort {
        case .recentlySaved: result.sort { $0.createdAt > $1.createdAt }
        case .oldest: result.sort { $0.createdAt < $1.createdAt }
        case .aToZ: result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .zToA: result.sort { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedDescending }
        case .recentlyViewed: result.sort { ($0.lastViewedAt ?? .distantPast) > ($1.lastViewedAt ?? .distantPast) }
        }
        return result
    }
}
