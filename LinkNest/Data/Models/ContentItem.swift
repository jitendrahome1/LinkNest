//
//  ContentItem.swift
//

import Foundation
import SwiftData

enum ContentPlatform: String, Codable, CaseIterable, Identifiable {
    case youtube, instagram, facebook, linkedin, x, website, other
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .youtube: "YouTube"
        case .instagram: "Instagram"
        case .facebook: "Facebook"
        case .linkedin: "LinkedIn"
        case .x: "X"
        case .website: "Website"
        case .other: "Other"
        }
    }

    /// Short badge text shown on thumbnails (prototype's monogram chip).
    var monogram: String {
        switch self {
        case .youtube: "YT"
        case .instagram: "IG"
        case .facebook: "fb"
        case .linkedin: "in"
        case .x: "X"
        case .website, .other: "ww"
        }
    }

    /// Badge background, from the prototype.
    var badgeHex: UInt32 {
        switch self {
        case .youtube: 0xC93F38
        case .instagram: 0xB23A80
        case .facebook: 0x3B6FC4
        case .linkedin: 0x20679E
        case .x: 0x33333B
        case .website, .other: 0x5A6472
        }
    }

    static func detect(from url: String) -> ContentPlatform {
        let u = url.lowercased()
        if u.contains("youtu") { return .youtube }
        if u.contains("instagram") { return .instagram }
        if u.contains("linkedin") { return .linkedin }
        if u.contains("x.com") || u.contains("twitter") { return .x }
        if u.contains("facebook") { return .facebook }
        return .website
    }
}

enum ContentType: String, Codable, CaseIterable, Identifiable {
    case video, article, post, website, pdf, other
    var id: String { rawValue }
    var displayName: String {
        switch self {
        case .video: "Video"
        case .article: "Article"
        case .post: "Post"
        case .website: "Website"
        case .pdf: "PDF"
        case .other: "Other"
        }
    }
    var pluralName: String {
        switch self {
        case .video: "Videos"
        case .article: "Articles"
        case .post: "Posts"
        case .website: "Websites"
        case .pdf: "PDFs"
        case .other: "Other"
        }
    }
}

@Model
final class ContentItem {
    @Attribute(.unique) var id: UUID
    var url: String
    var title: String
    var itemDescription: String
    var thumbnailURL: String?
    /// Hue (0–360) driving the gradient placeholder thumbnail, as in the prototype.
    var thumbnailHue: Double
    var platformRaw: String
    var contentTypeRaw: String
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

    // Video playback progress (VideoPlayerView).
    var playbackPositionSeconds: Double = 0
    var playbackDurationSeconds: Double = 0

    // PDF reading progress (PDFReaderView).
    var currentPage: Int = 1
    var totalPages: Int = 0
    var bookmarkedPages: [Int] = []

    var collection: ContentCollection?
    @Relationship(inverse: \Tag.items) var tags: [Tag]

    var platform: ContentPlatform {
        get { ContentPlatform(rawValue: platformRaw) ?? .other }
        set { platformRaw = newValue.rawValue }
    }
    var contentType: ContentType {
        get { ContentType(rawValue: contentTypeRaw) ?? .other }
        set { contentTypeRaw = newValue.rawValue }
    }

    init(id: UUID = UUID(),
         url: String,
         title: String,
         description: String = "",
         thumbnailURL: String? = nil,
         thumbnailHue: Double = 230,
         platform: ContentPlatform,
         contentType: ContentType,
         creatorName: String,
         creatorURL: String? = nil,
         duration: String? = nil,
         createdAt: Date = .now,
         lastViewedAt: Date? = nil,
         notes: String = "",
         isFavorite: Bool = false,
         isWatchLater: Bool = false,
         isCompleted: Bool = false,
         isArchived: Bool = false,
         collection: ContentCollection? = nil,
         tags: [Tag] = []) {
        self.id = id
        self.url = url
        self.title = title
        self.itemDescription = description
        self.thumbnailURL = thumbnailURL
        self.thumbnailHue = thumbnailHue
        self.platformRaw = platform.rawValue
        self.contentTypeRaw = contentType.rawValue
        self.creatorName = creatorName
        self.creatorURL = creatorURL
        self.duration = duration
        self.createdAt = createdAt
        self.updatedAt = createdAt
        self.lastViewedAt = lastViewedAt
        self.notes = notes
        self.isFavorite = isFavorite
        self.isWatchLater = isWatchLater
        self.isCompleted = isCompleted
        self.isArchived = isArchived
        self.collection = collection
        self.tags = tags
    }
}

extension ContentItem {
    /// "2h ago" style label matching the prototype.
    var savedAgo: String {
        guard Date.now.timeIntervalSince(createdAt) >= 60 else {
            return String(localized: "detail.justNow", defaultValue: "Just now")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: createdAt, relativeTo: .now)
    }

    var lastViewedLabel: String {
        guard let lastViewedAt else {
            return String(localized: "detail.notViewed", defaultValue: "Not yet")
        }
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: lastViewedAt, relativeTo: .now)
    }

    /// Fraction of the video watched, 0...1.
    var playbackProgress: Double {
        guard playbackDurationSeconds > 0 else { return 0 }
        return min(1, max(0, playbackPositionSeconds / playbackDurationSeconds))
    }

    /// Show a "Continue from mm:ss" resume prompt only for a real, unfinished position.
    var hasResumablePlayback: Bool {
        !isCompleted && playbackPositionSeconds > 5 && playbackDurationSeconds > 0 && playbackProgress < 0.97
    }

    /// Fraction of the PDF read, 0...1.
    var readingProgress: Double {
        guard totalPages > 0 else { return 0 }
        return min(1, max(0, Double(currentPage) / Double(totalPages)))
    }

    var hasResumableReading: Bool {
        !isCompleted && currentPage > 1 && totalPages > 0
    }
}
