//
//  SavedViewModel.swift
//  Holds the Saved screen's filter/sort/layout state; the actual
//  filtering is the pure FilterContentUseCase.
//

import Foundation
import Observation

/// Quick-action requests from Home ("Favorites", "Watch Later", "Recent").
enum SavedFilterRequest {
    case favorites, watchLater, recent
    /// Jumping in from Manage Tags — reuses the existing text search since
    /// FilterContentUseCase already matches a query against tag names.
    case tag(String)
}

@Observable
@MainActor
final class SavedViewModel {
    var filter = ContentFilter()
    var isGrid = false

    private let filterContent: FilterContentUseCase

    init(filterContent: FilterContentUseCase) {
        self.filterContent = filterContent
    }

    func apply(_ request: SavedFilterRequest?) {
        guard let request else { return }
        filter.reset()
        filter.segment = .all
        filter.sort = .recentlySaved
        switch request {
        case .favorites: filter.favoritesOnly = true
        case .watchLater: filter.watchLaterOnly = true
        case .recent: break
        case .tag(let name): filter.query = name
        }
    }

    func items(from all: [ContentItem]) -> [ContentItem] {
        filterContent(all, filter: filter)
    }
}
