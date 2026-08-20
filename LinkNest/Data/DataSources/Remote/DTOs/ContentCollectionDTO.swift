//
//  ContentCollectionDTO.swift
//  Mirrors the public.collections table.
//

import Foundation

struct ContentCollectionDTO: Codable {
    var id: UUID
    var userID: UUID
    var name: String
    var colorHex: Int
    var sortIndex: Int
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case userID = "user_id"
        case colorHex = "color_hex"
        case sortIndex = "sort_index"
        case createdAt = "created_at"
    }
}

extension ContentCollectionDTO {
    init(collection: ContentCollection, userID: UUID) {
        id = collection.id
        self.userID = userID
        name = collection.name
        colorHex = Int(collection.colorHex)
        sortIndex = collection.sortIndex
        createdAt = collection.createdAt
    }

    func apply(to collection: ContentCollection) {
        collection.name = name
        collection.colorHex = UInt32(truncatingIfNeeded: colorHex)
        collection.sortIndex = sortIndex
    }

    func makeCollection() -> ContentCollection {
        ContentCollection(id: id, name: name, colorHex: UInt32(truncatingIfNeeded: colorHex),
                          sortIndex: sortIndex, createdAt: createdAt)
    }
}
