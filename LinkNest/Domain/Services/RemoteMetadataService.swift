//
//  RemoteMetadataService.swift
//  Fetches real link metadata: YouTube via the keyless oEmbed endpoint,
//  everything else via the page's Open Graph tags. Falls back to the
//  canned MockMetadataService results when the network is unavailable
//  or the site blocks anonymous scraping.
//

import Foundation

struct RemoteMetadataService: MetadataService {
    let fallback: any MetadataService

    private var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 8
        config.timeoutIntervalForResource = 12
        return URLSession(configuration: config)
    }

    func fetchMetadata(for url: String) async throws -> LinkMetadata {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { throw MetadataError.invalidURL }
        let normalized = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard let pageURL = URL(string: normalized), pageURL.host != nil else {
            throw MetadataError.invalidURL
        }

        let platform = ContentPlatform.detect(from: normalized)
        if pageURL.pathExtension.lowercased() == "pdf" {
            return pdfMetadata(for: pageURL)
        }
        if platform == .youtube, let metadata = await fetchYouTube(pageURL) {
            return metadata
        }
        if let metadata = await fetchOpenGraph(pageURL, platform: platform) {
            return metadata
        }
        return try await fallback.fetchMetadata(for: normalized)
    }

    /// PDFs are rendered by PDFReaderView itself, so metadata only needs a
    /// readable title derived from the filename — no HTML/oEmbed to parse.
    private func pdfMetadata(for url: URL) -> LinkMetadata {
        let filename = url.deletingPathExtension().lastPathComponent
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "_", with: " ")
        let title = filename.isEmpty ? (url.host ?? "Document") : filename.capitalized
        return LinkMetadata(title: title,
                            creatorName: url.host ?? "Document",
                            platform: .website,
                            contentType: .pdf,
                            duration: nil,
                            thumbnailHue: Self.stableHue(for: url),
                            thumbnailURL: nil)
    }

    // MARK: - YouTube oEmbed

    private func fetchYouTube(_ url: URL) async -> LinkMetadata? {
        var components = URLComponents(string: "https://www.youtube.com/oembed")!
        components.queryItems = [
            URLQueryItem(name: "url", value: url.absoluteString),
            URLQueryItem(name: "format", value: "json")
        ]
        guard let oembedURL = components.url,
              let (data, response) = try? await session.data(from: oembedURL),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let title = json["title"] as? String else { return nil }

        return LinkMetadata(title: title,
                            creatorName: json["author_name"] as? String ?? "YouTube",
                            platform: .youtube,
                            contentType: .video,
                            duration: nil,
                            thumbnailHue: Self.stableHue(for: url),
                            thumbnailURL: json["thumbnail_url"] as? String)
    }

    // MARK: - Open Graph

    private func fetchOpenGraph(_ url: URL, platform: ContentPlatform) async -> LinkMetadata? {
        var request = URLRequest(url: url)
        // Some sites only serve OG tags to browser-like user agents.
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1",
                         forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, http.statusCode == 200 else { return nil }

        // Some PDFs are served from extensionless URLs; catch them by MIME type too.
        if (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased().contains("application/pdf") {
            return pdfMetadata(for: url)
        }

        let html = String(data: data.prefix(512 * 1024), encoding: .utf8)
            ?? String(data: data.prefix(512 * 1024), encoding: .isoLatin1)
        guard let html else { return nil }

        let ogTitle = Self.metaContent(in: html, key: "og:title")
        let pageTitle = Self.tagText(in: html, tag: "title")
        let image = Self.metaContent(in: html, key: "og:image")
        guard ogTitle != nil || pageTitle != nil || image != nil else { return nil }

        let siteName = Self.metaContent(in: html, key: "og:site_name")
        let ogType = Self.metaContent(in: html, key: "og:type") ?? ""
        let contentType: ContentType = ogType.contains("video") ? .video : Self.defaultType(for: platform)

        return LinkMetadata(title: (ogTitle ?? pageTitle ?? url.host ?? "Saved Link").decodingHTMLEntities,
                            creatorName: (siteName ?? url.host ?? platform.displayName).decodingHTMLEntities,
                            platform: platform,
                            contentType: contentType,
                            duration: nil,
                            thumbnailHue: Self.stableHue(for: url),
                            thumbnailURL: image?.decodingHTMLEntities)
    }

    private static func defaultType(for platform: ContentPlatform) -> ContentType {
        switch platform {
        case .youtube: .video
        case .instagram, .x, .facebook: .post
        case .linkedin, .website, .other: .article
        }
    }

    /// Matches <meta property="og:x" content="…"> with attributes in either order.
    private static func metaContent(in html: String, key: String) -> String? {
        let patterns = [
            "<meta[^>]+(?:property|name)=[\"']\(key)[\"'][^>]*content=[\"']([^\"']+)[\"']",
            "<meta[^>]+content=[\"']([^\"']+)[\"'][^>]*(?:property|name)=[\"']\(key)[\"']"
        ]
        for pattern in patterns {
            if let range = html.range(of: pattern, options: [.regularExpression, .caseInsensitive]),
               let match = html[range].range(of: "content=[\"']([^\"']+)[\"']", options: [.regularExpression, .caseInsensitive]) {
                let content = html[match].dropFirst("content='".count).dropLast(1)
                if !content.isEmpty { return String(content) }
            }
        }
        return nil
    }

    private static func tagText(in html: String, tag: String) -> String? {
        guard let range = html.range(of: "<\(tag)[^>]*>([^<]*)</\(tag)>", options: [.regularExpression, .caseInsensitive]) else { return nil }
        let fragment = html[range]
        guard let start = fragment.firstIndex(of: ">"), let end = fragment.lastIndex(of: "<") else { return nil }
        let text = fragment[fragment.index(after: start)..<end].trimmingCharacters(in: .whitespacesAndNewlines)
        return text.isEmpty ? nil : text
    }

    /// Deterministic hue per URL (djb2) so the gradient fallback is stable, not random.
    private static func stableHue(for url: URL) -> Double {
        var hash: UInt64 = 5381
        for byte in url.absoluteString.utf8 {
            hash = hash &* 33 &+ UInt64(byte)
        }
        return Double(hash % 360)
    }
}
