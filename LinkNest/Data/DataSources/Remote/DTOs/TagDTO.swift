//
//  TagDTO.swift
//  Mirrors the public.tags table.
//

import Foundation

struct TagDTO: Codable {
    var id: UUID
    var userID: UUID
    var name: String
    var createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id, name
        case userID = "user_id"
        case createdAt = "created_at"
    }
}

extension TagDTO {
    init(tag: Tag, userID: UUID) {
        id = tag.id
        self.userID = userID
        name = tag.name
        createdAt = tag.createdAt
    }

    func makeTag() -> Tag {
        Tag(id: id, name: name, createdAt: createdAt)
    }
}

/// A row in the content_item_tags join table.
struct ContentItemTagLinkDTO: Codable {
    var contentItemID: UUID
    var tagID: UUID
    var userID: UUID

    enum CodingKeys: String, CodingKey {
        case contentItemID = "content_item_id"
        case tagID = "tag_id"
        case userID = "user_id"
    }
}
