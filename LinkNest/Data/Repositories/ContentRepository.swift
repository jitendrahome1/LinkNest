//
//  ContentRepository.swift
//

import Foundation
import SwiftData

@MainActor
protocol ContentRepository: AnyObject {
    func all() -> [ContentItem]
    func active() -> [ContentItem]          // not archived
    func item(id: UUID) -> ContentItem?
    func insert(_ item: ContentItem)
    func delete(_ item: ContentItem)
    func markViewed(_ item: ContentItem)
    func save()
}

@MainActor
final class SwiftDataContentRepository: ContentRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func all() -> [ContentItem] {
        let descriptor = FetchDescriptor<ContentItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func active() -> [ContentItem] {
        let descriptor = FetchDescriptor<ContentItem>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func item(id: UUID) -> ContentItem? {
        let descriptor = FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    func insert(_ item: ContentItem) {
        context.insert(item)
        save()
    }

    func delete(_ item: ContentItem) {
        context.delete(item)
        save()
    }

    func markViewed(_ item: ContentItem) {
        item.lastViewedAt = .now
        save()
    }

    func save() {
        try? context.save()
    }
}
