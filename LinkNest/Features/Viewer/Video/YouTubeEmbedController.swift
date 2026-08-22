//
//  YouTubeEmbedController.swift
//  Drives the same LinkNestPlayerControls/LinkNestPlayerBottomBar used for
//  AVPlayer sources over YouTubePlayerKit's YouTubePlayer, so the visible
//  transport UI stays LinkNest's own design instead of YouTube's own
//  web-player chrome (small text, foreign styling). YouTubePlayerKit wraps
//  YouTube's official IFrame Player API (developers.google.com/youtube/iframe_api_reference)
//  — a maintained, ToS-compliant integration — never a raw stream URL.
//
//  `player` is exposed so the view layer can render it via YouTubePlayerKit's
//  own `YouTubePlayerView`; this controller only adds the observable
//  transport state (isPlaying/currentTime/duration) and command methods
//  matching VideoPlayerViewModel's shape, so the same control components
//  work against either one without caring which is behind them. Native
//  controls/fullscreen button are disabled (see `parameters` below) since
//  LinkNestPlayerControls/LinkNestPlayerBottomBar are the only visible
//  transport, in and out of fullscreen.
//

import Foundation
import Combine
import Observation
import YouTubePlayerKit

@Observable
@MainActor
final class YouTubeEmbedController {
    let videoID: String
    let player: YouTubePlayer

    private(set) var isPlaying = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    var isMuted = false {
        didSet {
            guard isMuted != oldValue else { return }
            Task { [player, isMuted] in try? await (isMuted ? player.mute() : player.unmute()) }
        }
    }
    var speed: Double = 1 {
        didSet {
            guard speed != oldValue else { return }
            Task { [player, speed] in try? await player.set(playbackRate: .init(value: speed)) }
        }
    }

    private var cancellables: Set<AnyCancellable> = []

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    init(videoID: String) {
        self.videoID = videoID
        player = YouTubePlayer(
            source: .video(id: videoID),
            parameters: .init(
                autoPlay: false,
                showControls: false,
                showFullscreenButton: false
            )
        )
        // YouTube's own iframe still handles raw touches (tap-to-pause,
        // its branded title/share/"up next" chrome) even with showControls
        // disabled — our SwiftUI overlay sits visually on top but the
        // webView underneath was still first responder for touches, so
        // taps intended for LinkNestPlayerControls could pause the video via
        // YouTube's own handler and surface YouTube's own (un-hideable)
        // paused-state UI instead of ours. `player.webView` isn't public,
        // so the actual disabling happens in YouTubeWebViewInteractionDisabler
        // (VideoPlayerView.swift), which finds the WKWebView by walking the
        // UIKit hierarchy instead.

        player.playbackStatePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in self?.isPlaying = (state == .playing) }
            .store(in: &cancellables)
        player.currentTimePublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in self?.currentTime = time.converted(to: .seconds).value }
            .store(in: &cancellables)
        player.durationPublisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] time in self?.duration = time.converted(to: .seconds).value }
            .store(in: &cancellables)
    }

    func togglePlay() { isPlaying ? pause() : play() }
    func play() { Task { [player] in try? await player.play() } }
    func pause() { Task { [player] in try? await player.pause() } }
    func skipBack() { Task { [player] in try? await player.rewind(by: .init(value: 10, unit: .seconds)) } }
    func skipForward() { Task { [player] in try? await player.fastForward(by: .init(value: 10, unit: .seconds)) } }

    /// Live drag preview — local only, no command sent until commitScrub.
    func scrub(toFraction fraction: Double) {
        guard duration > 0 else { return }
        currentTime = fraction * duration
    }

    func commitScrub() { seek(to: currentTime) }

    func seek(to seconds: Double) {
        let clamped = min(max(0, seconds), duration > 0 ? duration : seconds)
        currentTime = clamped
        Task { [player] in try? await player.seek(to: .init(value: clamped, unit: .seconds)) }
    }
}
