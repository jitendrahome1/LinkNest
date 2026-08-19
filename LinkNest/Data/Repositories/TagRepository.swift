//
//  TagRepository.swift
//

import Foundation
import SwiftData

@MainActor
protocol TagRepository: AnyObject {
    func all() -> [Tag]
    func findOrCreate(named name: String) -> Tag
    func delete(_ tag: Tag)
}

@MainActor
final class SwiftDataTagRepository: TagRepository {
    private let context: ModelContext

    init(context: ModelContext) {
        self.context = context
    }

    func all() -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func findOrCreate(named name: String) -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing = all().first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let tag = Tag(name: trimmed)
        context.insert(tag)
        try? context.save()
        return tag
    }

    func delete(_ tag: Tag) {
        context.delete(tag)
        try? context.save()
    }
}
