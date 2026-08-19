//
//  SearchService.swift
//  Global search across items, collections and tags — grouped the same
//  way as the prototype's Search screen. Future-ready for semantic
//  search: swap the matching strategy behind the same result type.
//

import Foundation

struct SearchResults {
    var collections: [ContentCollection] = []
    var tags: [Tag] = []
    var items: [ContentItem] = []
    var isEmpty: Bool { collections.isEmpty && tags.isEmpty && items.isEmpty }
}

@MainActor
final class SearchService {
    private let content: any ContentRepository
    private let collections: any CollectionRepository
    private let tags: any TagRepository

    init(content: any ContentRepository,
         collections: any CollectionRepository,
         tags: any TagRepository) {
        self.content = content
        self.collections = collections
        self.tags = tags
    }

    func search(_ query: String) -> SearchResults {
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        guard !q.isEmpty else { return SearchResults() }

        let items = content.active().filter { item in
            item.title.lowercased().contains(q)
                || item.creatorName.lowercased().contains(q)
                || item.notes.lowercased().contains(q)
                || item.platform.displayName.lowercased().contains(q)
                || item.tags.contains { $0.name.lowercased().contains(q) }
                || (item.collection?.name.lowercased().contains(q) ?? false)
        }
        let matchedCollections = collections.all().filter { $0.name.lowercased().contains(q) }
        let matchedTags = tags.all().filter { $0.name.lowercased().contains(q) }

        return SearchResults(collections: matchedCollections, tags: matchedTags, items: items)
    }
}
