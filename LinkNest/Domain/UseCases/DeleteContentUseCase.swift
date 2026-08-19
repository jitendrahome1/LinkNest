//
//  DeleteContentUseCase.swift
//  Soft-delete semantics land later (Recently Deleted); for now archive
//  is the soft state and delete removes the record.
//

import Foundation

@MainActor
struct DeleteContentUseCase {
    let content: any ContentRepository

    func archive(_ item: ContentItem) {
        item.isArchived = true
        item.updatedAt = .now
        content.save()
    }

    func delete(_ item: ContentItem) {
        content.delete(item)
    }
}
