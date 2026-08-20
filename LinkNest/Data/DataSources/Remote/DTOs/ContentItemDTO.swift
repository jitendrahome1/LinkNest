//
//  ContentItemDTO.swift
//  Mirrors the public.content_items table. Row id == ContentItem.id,
//  so local and remote records share one primary key — no id mapping.
//

import Foundation

struct ContentItemDTO: Codable {
    var id: UUID
    var userID: UUID
    var url: String
    var title: String
    var description: String
    var thumbnailURL: String?
    var thumbnailHue: Double
    var platform: String
    var contentType: String
    var creatorName: String
    var creatorURL: String?
    var duration: String?
    var createdAt: Date
    var updatedAt: Date
    var lastViewedAt: Date?
    var notes: String
    var summary: String?
    var isFavorite: Bool
    var isWatchLater: Bool
    var isCompleted: Bool
    var isArchived: Bool
    var playbackPositionSeconds: Double
    var playbackDurationSeconds: Double
    var currentPage: Int
    var totalPages: Int
    var bookmarkedPages: [Int]
    var collectionID: UUID?

    enum CodingKeys: String, CodingKey {
        case id, url, title, description, platform, notes, summary, duration
        case userID = "user_id"
        case thumbnailURL = "thumbnail_url"
        case thumbnailHue = "thumbnail_hue"
        case contentType = "content_type"
        case creatorName = "creator_name"
        case creatorURL = "creator_url"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case lastViewedAt = "last_viewed_at"
        case isFavorite = "is_favorite"
        case isWatchLater = "is_watch_later"
        case isCompleted = "is_completed"
        case isArchived = "is_archived"
        case playbackPositionSeconds = "playback_position_seconds"
        case playbackDurationSeconds = "playback_duration_seconds"
        case currentPage = "current_page"
        case totalPages = "total_pages"
        case bookmarkedPages = "bookmarked_pages"
        case collectionID = "collection_id"
    }
}

extension ContentItemDTO {
    init(item: ContentItem, userID: UUID) {
        id = item.id
        self.userID = userID
        url = item.url
        title = item.title
        description = item.itemDescription
        thumbnailURL = item.thumbnailURL
        thumbnailHue = item.thumbnailHue
        platform = item.platformRaw
        contentType = item.contentTypeRaw
        creatorName = item.creatorName
        creatorURL = item.creatorURL
        duration = item.duration
        createdAt = item.createdAt
        updatedAt = item.updatedAt
        lastViewedAt = item.lastViewedAt
        notes = item.notes
        summary = item.summary
        isFavorite = item.isFavorite
        isWatchLater = item.isWatchLater
        isCompleted = item.isCompleted
        isArchived = item.isArchived
        playbackPositionSeconds = item.playbackPositionSeconds
        playbackDurationSeconds = item.playbackDurationSeconds
        currentPage = item.currentPage
        totalPages = item.totalPages
        bookmarkedPages = item.bookmarkedPages
        collectionID = item.collection?.id
    }

    /// Applies the remote fields onto a local item (used when pulling/merging).
    func apply(to item: ContentItem) {
        item.url = url
        item.title = title
        item.itemDescription = description
        item.thumbnailURL = thumbnailURL
        item.thumbnailHue = thumbnailHue
        item.platformRaw = platform
        item.contentTypeRaw = contentType
        item.creatorName = creatorName
        item.creatorURL = creatorURL
        item.duration = duration
        item.updatedAt = updatedAt
        item.lastViewedAt = lastViewedAt
        item.notes = notes
        item.summary = summary
        item.isFavorite = isFavorite
        item.isWatchLater = isWatchLater
        item.isCompleted = isCompleted
        item.isArchived = isArchived
        item.playbackPositionSeconds = playbackPositionSeconds
        item.playbackDurationSeconds = playbackDurationSeconds
        item.currentPage = currentPage
        item.totalPages = totalPages
        item.bookmarkedPages = bookmarkedPages
    }

    /// A freshly constructed local item carrying every remote field —
    /// including the ones `ContentItem.init` doesn't take directly.
    func makeItem() -> ContentItem {
        let item = ContentItem(
            id: id,
            url: url,
            title: title,
            description: description,
            thumbnailURL: thumbnailURL,
            thumbnailHue: thumbnailHue,
            platform: ContentPlatform(rawValue: platform) ?? .other,
            contentType: ContentType(rawValue: contentType) ?? .other,
            creatorName: creatorName,
            creatorURL: creatorURL,
            duration: duration,
            createdAt: createdAt,
            lastViewedAt: lastViewedAt,
            notes: notes,
            isFavorite: isFavorite,
            isWatchLater: isWatchLater,
            isCompleted: isCompleted,
            isArchived: isArchived
        )
        apply(to: item)
        return item
    }
}
