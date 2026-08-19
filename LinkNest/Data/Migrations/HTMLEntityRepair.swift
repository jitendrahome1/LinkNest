//
//  HTMLEntityRepair.swift
//  A save made before decodingHTMLEntities existed can have raw entities
//  (&#x939; …) baked into its title/creator/thumbnail. Idempotent and cheap,
//  so it just runs every launch rather than needing a one-time-migration flag.
//

import Foundation

enum HTMLEntityRepair {
    @MainActor
    static func run(content: any ContentRepository) {
        var didChange = false
        for item in content.all() {
            let decodedTitle = item.title.decodingHTMLEntities
            if decodedTitle != item.title { item.title = decodedTitle; didChange = true }

            let decodedCreator = item.creatorName.decodingHTMLEntities
            if decodedCreator != item.creatorName { item.creatorName = decodedCreator; didChange = true }

            if let thumbnailURL = item.thumbnailURL {
                let decoded = thumbnailURL.decodingHTMLEntities
                if decoded != thumbnailURL { item.thumbnailURL = decoded; didChange = true }
            }
        }
        if didChange { content.save() }
    }
}
