//
//  YouTubeEmbedController.swift
//  Drives the same LinkNestPlayerControls/LinkNestPlayerBottomBar used for
//  AVPlayer sources over YouTube's officially embedded IFrame Player, so
//  the visible transport UI stays LinkNest's own design instead of
//  YouTube's own web-player chrome (small text, foreign styling). Talks to
//  the player exclusively through the official YT.Player JS API (see the
//  wrapper page built in WebPlayerView) — commands out, state updates in
//  via a WKScriptMessageHandler bridge. Never touches a raw stream URL.
//

import Foundation
@preconcurrency import WebKit
import Observation

@Observable
@MainActor
final class YouTubeEmbedController {
    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    var isMuted = false {
        didSet { evaluate(isMuted ? "player && player.mute();" : "player && player.unMute();") }
    }
    var speed: Double = 1 {
        didSet { evaluate("player && player.setPlaybackRate(\(speed));") }
    }

    weak var webView: WKWebView?

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    func togglePlay() { isPlaying ? pause() : play() }
    func play() { evaluate("player && player.playVideo();") }
    func pause() { evaluate("player && player.pauseVideo();") }
    func skipBack() { seek(to: currentTime - 10) }
    func skipForward() { seek(to: currentTime + 10) }

    /// Live drag preview — local only, no command sent until commitScrub.
    func scrub(toFraction fraction: Double) {
        guard duration > 0 else { return }
        currentTime = fraction * duration
    }

    func commitScrub() { seek(to: currentTime) }

    func seek(to seconds: Double) {
        let clamped = min(max(0, seconds), duration > 0 ? duration : seconds)
        currentTime = clamped
        evaluate("player && player.seekTo(\(clamped), true);")
    }

    /// Reapplies local state to a freshly (re)created player instance —
    /// used when the inline embed is torn down and rebuilt for fullscreen,
    /// since that's a new WKWebView/YT.Player, not the same one.
    func resumeAfterReady() {
        if currentTime > 0 { evaluate("player && player.seekTo(\(currentTime), true);") }
        if isMuted { evaluate("player && player.mute();") }
        if speed != 1 { evaluate("player && player.setPlaybackRate(\(speed));") }
        if isPlaying { play() }
    }

    /// Parses bridge messages relayed from the wrapper page's JS: a
    /// periodic time-code tick, or a YT.Player onStateChange event
    /// (1 = playing, 2 = paused — see the IFrame API's documented states).
    func handle(_ body: [String: Any]) {
        guard let type = body["type"] as? String else { return }
        switch type {
        case "tick":
            if let t = body["currentTime"] as? Double { currentTime = t }
            if let d = body["duration"] as? Double, d > 0 { duration = d }
        case "stateChange":
            if let state = body["state"] as? Int { isPlaying = (state == 1) }
        default: break
        }
    }

    private func evaluate(_ js: String) {
        webView?.evaluateJavaScript(js)
    }
}
