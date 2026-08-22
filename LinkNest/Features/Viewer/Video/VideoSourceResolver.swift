//
//  VideoSourceResolver.swift
//  Classifies a saved URL into what AVPlayer/WKWebView can actually do
//  with it. Cheapest/most-certain checks first (extension sniff, then a
//  no-network host registry for platforms with a legitimate public embed
//  or API surface), and only falls through to a bounded network probe
//  for truly unrecognized hosts. Stays 100% client-side, only calls
//  legitimate public endpoints (Reddit's own post JSON, Streamable's
//  public video-info endpoint), and never attempts to extract a raw
//  stream URL from YouTube — playback is always YouTube's own official
//  IFrame Player, embedded via WebPlayerView, never a raw stream fed to
//  AVPlayer. See WebPlayerView's comment for how the embed is made to
//  actually pass YouTube's origin verification.
//

import Foundation

enum VideoSource: Equatable {
    case direct(URL)
    case hls(URL)
    case embeddable(URL)
    case youTube(videoID: String)
    case webPage(URL)
    case unsupported(reason: String)
}

protocol VideoSourceResolver: Sendable {
    func resolve(_ urlString: String) async -> VideoSource
}

struct DefaultVideoSourceResolver: VideoSourceResolver {
    private static let streamableExtensions: Set<String> = ["mp4", "mov", "m4v", "webm"]
    private static let manifestExtensions: Set<String> = ["m3u8"]
    /// Reddit and Streamable's anti-bot layers are more permissive of a
    /// browser-looking UA than URLSession's default CFNetwork string.
    private static let browserUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    private var session: URLSession {
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 4
        config.timeoutIntervalForResource = 5
        return URLSession(configuration: config)
    }

    func resolve(_ urlString: String) async -> VideoSource {
        guard let url = URL(string: urlString), url.scheme?.hasPrefix("http") == true, let host = url.host?.lowercased() else {
            return .unsupported(reason: String(localized: "player.invalidURL", defaultValue: "This link isn't a valid video URL."))
        }

        // 1. Extension/manifest sniff — no network call.
        let ext = url.pathExtension.lowercased()
        if Self.manifestExtensions.contains(ext) || urlString.lowercased().contains(".m3u8") { return .hls(url) }
        if Self.streamableExtensions.contains(ext) { return .direct(url) }

        // 2. Known-host registry — no network call except where the platform
        // itself requires resolving a page/permalink to a real media URL.
        if host.contains("youtu") {
            if let videoID = Self.youTubeVideoID(from: url) { return .youTube(videoID: videoID) }
            return .webPage(url)
        }
        if let embed = Self.vimeoEmbed(host: host, url: url) { return .embeddable(embed) }
        if let embed = Self.dailymotionEmbed(host: host, url: url) { return .embeddable(embed) }
        if let embed = Self.twitchEmbed(host: host, url: url) { return .embeddable(embed) }
        if let embed = Self.facebookEmbed(host: host, url: url) { return .embeddable(embed) }
        if host.contains("instagram") || host.contains("facebook") || host.contains("linkedin")
            || host.contains("x.com") || host.contains("twitter") {
            return .webPage(url)
        }
        if host == "v.redd.it" {
            // Bare CDN link, no recoverable post permalink to resolve real
            // audio+video HLS from — the raw stream is video-only. Playing
            // it silently with no sound would be more confusing than
            // Open Original, so route straight to the web fallback.
            return .webPage(url)
        }
        if host.contains("reddit.com") {
            if let hls = await resolveReddit(url) { return .hls(hls) }
            return .webPage(url)
        }
        if host.contains("streamable.com") {
            if let direct = await resolveStreamable(url) { return .direct(direct) }
            return .webPage(url)
        }

        // 3. Bounded HEAD sniff for unrecognized hosts (fixes extensionless
        // direct CDN/S3/Supabase-storage links that used to be assumed
        // playable with no verification at all).
        return await sniff(url)
    }

    // MARK: - YouTube video ID extraction (regex/query only, no network)

    private static func youTubeVideoID(from url: URL) -> String? {
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let v = components.queryItems?.first(where: { $0.name == "v" })?.value, !v.isEmpty {
            return v
        }
        if let id = firstMatch(in: url.absoluteString, pattern: #"(?:youtu\.be/|youtube\.com/(?:shorts|embed|live)/)([A-Za-z0-9_-]+)"#) {
            return id
        }
        return nil
    }

    // MARK: - Host-specific embed URL builders (regex/host only, no network)

    private static func vimeoEmbed(host: String, url: URL) -> URL? {
        guard host.contains("vimeo.com") else { return nil }
        guard let id = firstMatch(in: url.absoluteString, pattern: #"vimeo\.com/(?:.*/)?(\d+)"#) else { return nil }
        return URL(string: "https://player.vimeo.com/video/\(id)")
    }

    private static func dailymotionEmbed(host: String, url: URL) -> URL? {
        guard host.contains("dailymotion.com") || host.contains("dai.ly") else { return nil }
        guard let id = firstMatch(in: url.absoluteString, pattern: #"(?:dailymotion\.com/(?:embed/)?video/|dai\.ly/)([a-zA-Z0-9]+)"#) else { return nil }
        return URL(string: "https://www.dailymotion.com/embed/video/\(id)")
    }

    /// Best-effort: Twitch validates a `parent` query param, which has no
    /// real meaning inside a native WKWebView. If it blocks, WebPlayerView's
    /// own load-verification already falls back to Open Original — same as
    /// any other unrenderable embed — so this is safe to attempt regardless.
    private static func twitchEmbed(host: String, url: URL) -> URL? {
        guard host.contains("twitch.tv") else { return nil }
        if let clip = firstMatch(in: url.absoluteString, pattern: #"clips\.twitch\.tv/([A-Za-z0-9_-]+)"#) {
            return URL(string: "https://clips.twitch.tv/embed?clip=\(clip)&parent=linknest.app&autoplay=false")
        }
        if let vod = firstMatch(in: url.absoluteString, pattern: #"twitch\.tv/videos/(\d+)"#) {
            return URL(string: "https://player.twitch.tv/?video=\(vod)&parent=linknest.app&autoplay=false")
        }
        return nil
    }

    /// Facebook video/watch/reel permalinks never expose a direct media file
    /// (AVPlayer has nothing to stream) and loading the raw page in a
    /// WKWebView just hits Facebook's login wall. Facebook's own Video
    /// Embed Plugin (developers.facebook.com/docs/plugins/embedded-video-player)
    /// is built exactly for this: it renders a public video's player without
    /// requiring the viewer to be logged in, since it's designed to be
    /// embedded on third-party sites. Only used for permalink shapes that
    /// are unambiguously a single video — a bare profile/group/post link has
    /// no video for the plugin to target.
    private static func facebookEmbed(host: String, url: URL) -> URL? {
        guard host.contains("facebook.com") else { return nil }
        let path = url.path.lowercased()
        guard path.contains("/videos/") || path.contains("/watch") || path.contains("/reel/") else { return nil }
        guard let encodedHref = url.absoluteString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else { return nil }
        return URL(string: "https://www.facebook.com/plugins/video.php?href=\(encodedHref)&show_text=false")
    }

    private static func firstMatch(in string: String, pattern: String) -> String? {
        guard let range = string.range(of: pattern, options: .regularExpression) else { return nil }
        guard let idRange = string[range].range(of: #"[A-Za-z0-9_-]+$"#, options: .regularExpression) else { return nil }
        return String(string[range][idRange])
    }

    // MARK: - Reddit (public post-JSON, not a private API)

    private func resolveReddit(_ url: URL) async -> URL? {
        guard url.absoluteString.contains("/comments/") else { return nil }
        let withoutQuery = url.absoluteString.split(separator: "?").first.map(String.init) ?? url.absoluteString
        let trimmed = withoutQuery.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard let jsonURL = URL(string: trimmed + ".json") else { return nil }
        var request = URLRequest(url: jsonURL)
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [Any],
              let listing = json.first as? [String: Any],
              let listingData = listing["data"] as? [String: Any],
              let children = listingData["children"] as? [[String: Any]],
              let postData = children.first?["data"] as? [String: Any],
              let media = (postData["secure_media"] ?? postData["media"]) as? [String: Any],
              let redditVideo = media["reddit_video"] as? [String: Any],
              let hlsURLString = redditVideo["hls_url"] as? String,
              let hlsURL = URL(string: hlsURLString) else { return nil }
        return hlsURL
    }

    // MARK: - Streamable (public unauthenticated video-info endpoint)

    private func resolveStreamable(_ url: URL) async -> URL? {
        guard let shortcode = Self.firstMatch(in: url.path, pattern: #"[A-Za-z0-9]+$"#) else { return nil }
        guard let infoURL = URL(string: "https://api.streamable.com/videos/\(shortcode)") else { return nil }
        var request = URLRequest(url: infoURL)
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        guard let (data, response) = try? await session.data(for: request),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let files = json["files"] as? [String: Any],
              let mp4 = files["mp4"] as? [String: Any],
              var mp4URLString = mp4["url"] as? String else { return nil }
        if mp4URLString.hasPrefix("//") { mp4URLString = "https:" + mp4URLString }
        return URL(string: mp4URLString)
    }

    // MARK: - Generic fallback: bounded HEAD sniff

    private func sniff(_ url: URL) async -> VideoSource {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.setValue(Self.browserUserAgent, forHTTPHeaderField: "User-Agent")
        guard let (_, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            return .webPage(url)
        }
        let contentType = (http.value(forHTTPHeaderField: "Content-Type") ?? "").lowercased()
        if contentType.contains("mpegurl") { return .hls(url) }
        if contentType.hasPrefix("video/") { return .direct(url) }
        return .webPage(url)
    }
}
