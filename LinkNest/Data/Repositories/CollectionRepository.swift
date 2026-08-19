//
//  CollectionRepository.swift
//

import Foundation
import SwiftData

@MainActor
protocol CollectionRepository: AnyObject {
    func all() -> [ContentCollection]
    func collection(id: UUID) -> ContentCollection?
    func insert(_ collection: ContentCollection)
    func rename(_ collection: ContentCollection, to name: String)
    func delete(_ collection: ContentCollection)
}

@MainActor
final class SwiftDataCollectionRepository: CollectionRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func all() -> [ContentCollection] {
        let descriptor = FetchDescriptor<ContentCollection>(sortBy: [SortDescriptor(\.sortIndex)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func collection(id: UUID) -> ContentCollection? {
        let descriptor = FetchDescriptor<ContentCollection>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    func insert(_ collection: ContentCollection) {
        collection.sortIndex = (all().map(\.sortIndex).max() ?? -1) + 1
        context.insert(collection)
        try? context.save()
    }

    func rename(_ collection: ContentCollection, to name: String) {
        collection.name = name
        try? context.save()
    }

    func delete(_ collection: ContentCollection) {
        context.delete(collection)
        try? context.save()
    }
}
