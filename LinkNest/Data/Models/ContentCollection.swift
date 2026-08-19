//
//  ContentCollection.swift
//  Named ContentCollection to avoid clashing with Swift.Collection.
//

import Foundation
import SwiftData

@Model
final class ContentCollection {
    @Attribute(.unique) var id: UUID
    var name: String
    /// Accent color for the icon tile, e.g. 0x4A50DB.
    var colorHex: UInt32
    var sortIndex: Int
    var createdAt: Date

    @Relationship(deleteRule: .nullify, inverse: \ContentItem.collection)
    var items: [ContentItem]

    var initial: String { String(name.prefix(1)).uppercased() }
    var activeItemCount: Int { items.filter { !$0.isArchived }.count }

    init(id: UUID = UUID(),
         name: String,
         colorHex: UInt32,
         sortIndex: Int = 0,
         createdAt: Date = .now,
         items: [ContentItem] = []) {
        self.id = id
        self.name = name
        self.colorHex = colorHex
        self.sortIndex = sortIndex
        self.createdAt = createdAt
        self.items = items
    }
}
