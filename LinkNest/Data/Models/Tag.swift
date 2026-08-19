//
//  Tag.swift
//

import Foundation
import SwiftData

@Model
final class Tag {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date

    var items: [ContentItem]

    var usageCount: Int { items.count }

    init(id: UUID = UUID(), name: String, createdAt: Date = .now, items: [ContentItem] = []) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.items = items
    }
}
