//
//  MetadataService.swift
//  Resolves link metadata for the Save flow. The mock mirrors the
//  prototype's simulated fetch (~0.9s, canned result per platform).
//  Replace with an APIClient/LinkPresentation implementation later.
//

import Foundation

struct LinkMetadata: Equatable, Sendable {
    var title: String
    var creatorName: String
    var platform: ContentPlatform
    var contentType: ContentType
    var duration: String?
    var thumbnailHue: Double
    var thumbnailURL: String? = nil
    var description: String = ""
}

enum MetadataError: Error, LocalizedError {
    case invalidURL
    case unavailable

    var errorDescription: String? {
        switch self {
        case .invalidURL: String(localized: "error.invalidLink", defaultValue: "Paste or enter a valid link first.")
        case .unavailable: String(localized: "error.metadata", defaultValue: "Couldn't load details for this link.")
        }
    }
}

protocol MetadataService: Sendable {
    func fetchMetadata(for url: String) async throws -> LinkMetadata
}

struct MockMetadataService: MetadataService {
    func fetchMetadata(for url: String) async throws -> LinkMetadata {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw MetadataError.invalidURL }
        try await Task.sleep(for: .milliseconds(900))

        switch ContentPlatform.detect(from: trimmed) {
        case .youtube:
            return LinkMetadata(title: "Designing Calm Interfaces at Scale", creatorName: "Design Everyday",
                                platform: .youtube, contentType: .video, duration: "18:24", thumbnailHue: 210)
        case .instagram:
            return LinkMetadata(title: "Grid systems in the wild", creatorName: "@type.wise",
                                platform: .instagram, contentType: .post, thumbnailHue: 340)
        case .x:
            return LinkMetadata(title: "Thread: what makes docs great", creatorName: "@worknotes",
                                platform: .x, contentType: .post, thumbnailHue: 190)
        case .linkedin:
            return LinkMetadata(title: "Hiring for judgment, not keywords", creatorName: "Priya Sharma",
                                platform: .linkedin, contentType: .article, thumbnailHue: 210)
        case .facebook:
            return LinkMetadata(title: "Community projects worth copying", creatorName: "Builders Club",
                                platform: .facebook, contentType: .post, thumbnailHue: 60)
        case .website, .other:
            return LinkMetadata(title: "The Art of Doing Less, Better", creatorName: "Field Notes",
                                platform: .website, contentType: .article, thumbnailHue: 80)
        }
    }
}
