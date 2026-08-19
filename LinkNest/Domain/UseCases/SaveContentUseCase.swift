//
//  SaveContentUseCase.swift
//

import Foundation

@MainActor
struct SaveContentUseCase {
    let content: any ContentRepository
    let tags: any TagRepository

    struct Input {
        var url: String
        var metadata: LinkMetadata
        var collection: ContentCollection?
        var tagNames: [String]
        var notes: String
        var isFavorite: Bool
        var isWatchLater: Bool
    }

    @discardableResult
    func callAsFunction(_ input: Input) -> ContentItem {
        let item = ContentItem(
            url: input.url,
            title: input.metadata.title,
            description: input.metadata.description,
            thumbnailURL: input.metadata.thumbnailURL,
            thumbnailHue: input.metadata.thumbnailHue,
            platform: input.metadata.platform,
            contentType: input.metadata.contentType,
            creatorName: input.metadata.creatorName,
            duration: input.metadata.duration,
            notes: input.notes,
            isFavorite: input.isFavorite,
            isWatchLater: input.isWatchLater,
            collection: input.collection,
            tags: input.tagNames.map { tags.findOrCreate(named: $0) }
        )
        content.insert(item)
        return item
    }
}
