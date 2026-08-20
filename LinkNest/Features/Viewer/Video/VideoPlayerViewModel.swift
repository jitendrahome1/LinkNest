//
//  VideoPlayerViewModel.swift
//  Owns the AVPlayer: load/error/buffering state, transport controls,
//  speed, mute, and playback-progress persistence onto the ContentItem
//  via the existing ContentRepository — no separate playback store.
//

import Foundation
import AVFoundation
import Observation

@Observable
@MainActor
final class VideoPlayerViewModel {
    enum Phase: Equatable {
        case loading
        case ready
        /// The saved URL isn't a direct media file (e.g. a YouTube page URL) —
        /// AVPlayer has nothing it can stream. Not a bug, just an unsupported source.
        case unsupportedSource
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    var isMuted = false {
        didSet { player.isMuted = isMuted }
    }
    var speed: Double = 1 {
        didSet { if isPlaying { player.rate = Float(speed) } }
    }

    /// Shown once, before playback starts, when there's meaningful saved progress.
    var showResumePrompt = false

    let player = AVPlayer()
    let item: ContentItem

    private let contentRepository: any ContentRepository
    private var timeObserver: Any?
    private var loadTask: Task<Void, Never>?
    private var failureObserver: NSObjectProtocol?
    private var bufferingObserver: NSObjectProtocol?
    private var endObserver: NSObjectProtocol?
    private var lastPersistedAt: Date = .distantPast
    private var didMarkCompleted = false

    static let skipInterval: Double = 10
    private static let streamableExtensions: Set<String> = ["mp4", "mov", "m4v", "webm", "m3u8"]

    var progress: Double {
        guard duration > 0 else { return 0 }
        return min(1, max(0, currentTime / duration))
    }

    init(item: ContentItem, contentRepository: any ContentRepository) {
        self.item = item
        self.contentRepository = contentRepository
        duration = item.playbackDurationSeconds
        currentTime = item.playbackPositionSeconds
        try? AVAudioSession.sharedInstance().setCategory(.playback)
    }

    func load() {
        phase = .loading
        guard let url = URL(string: item.url), url.scheme?.hasPrefix("http") == true else {
            phase = .failed(String(localized: "player.invalidURL", defaultValue: "This link isn't a valid video URL."))
            return
        }
        guard isLikelyDirectlyPlayable(url) else {
            // Constructing WKWebView is heavy; doing it the instant this view
            // pushes competes with the navigation transition's own animation
            // for the main thread and shows up as a stutter. Give the push a
            // beat to finish — the loading spinner covers the wait either way.
            loadTask?.cancel()
            loadTask = Task { [weak self] in
                try? await Task.sleep(for: .milliseconds(350))
                guard !Task.isCancelled, let self else { return }
                self.phase = .unsupportedSource
            }
            return
        }

        loadTask?.cancel()
        loadTask = Task { [weak self] in
            guard let self else { return }
            let asset = AVURLAsset(url: url)
            do {
                let (isPlayable, durationTime) = try await asset.load(.isPlayable, .duration)
                guard !Task.isCancelled else { return }
                guard isPlayable else {
                    self.phase = .failed(String(localized: "player.loadFailed", defaultValue: "This video couldn't be loaded."))
                    return
                }
                let playerItem = AVPlayerItem(asset: asset)
                self.player.replaceCurrentItem(with: playerItem)
                self.player.isMuted = self.isMuted
                self.attachTimeObserver()
                self.watchBuffering(of: playerItem)
                self.watchFailures(of: playerItem)
                self.watchPlaybackEnd(of: playerItem)

                let seconds = durationTime.seconds
                self.duration = seconds.isFinite && seconds > 0 ? seconds : self.item.playbackDurationSeconds
                self.item.playbackDurationSeconds = self.duration
                self.phase = .ready
                if self.item.hasResumablePlayback {
                    self.showResumePrompt = true
                } else {
                    self.play()
                }
            } catch {
                guard !Task.isCancelled else { return }
                self.phase = .failed(error.localizedDescription)
            }
        }
    }

    func retry() {
        detachObservers()
        didMarkCompleted = false
        load()
    }

    // MARK: - Transport

    func togglePlay() {
        if isPlaying { pause() } else { play() }
    }

    func play() {
        // At-end videos don't advance on play() until seeked back to the start.
        if duration > 0, currentTime >= duration - 0.1 {
            seek(to: 0, precise: true)
        }
        player.play()
        player.rate = Float(speed)
        isPlaying = true
    }

    func pause() {
        player.pause()
        isPlaying = false
        persist(force: true)
    }

    func skipBack() { seek(to: currentTime - Self.skipInterval) }
    func skipForward() { seek(to: currentTime + Self.skipInterval) }

    /// Live drag preview — cheap seek, doesn't need to be frame-accurate.
    func scrub(toFraction fraction: Double) {
        guard duration > 0 else { return }
        currentTime = fraction * duration
        player.seek(to: CMTime(seconds: currentTime, preferredTimescale: 600),
                    toleranceBefore: .positiveInfinity, toleranceAfter: .positiveInfinity)
    }

    /// Precise seek once the user releases the scrub bar.
    func commitScrub() {
        seek(to: currentTime, precise: true)
        persist(force: true)
    }

    func seek(to seconds: Double, precise: Bool = false) {
        let clamped = min(max(0, seconds), duration > 0 ? duration : seconds)
        currentTime = clamped
        let tolerance: CMTime = precise ? .zero : CMTime(seconds: 0.25, preferredTimescale: 600)
        player.seek(to: CMTime(seconds: clamped, preferredTimescale: 600),
                    toleranceBefore: tolerance, toleranceAfter: tolerance)
        persist(force: true)
    }

    func continueFromSaved() {
        showResumePrompt = false
        seek(to: item.playbackPositionSeconds, precise: true)
        play()
    }

    func startOver() {
        showResumePrompt = false
        seek(to: 0, precise: true)
        play()
    }

    // MARK: - Source detection

    private func isLikelyDirectlyPlayable(_ url: URL) -> Bool {
        if Self.streamableExtensions.contains(url.pathExtension.lowercased()) { return true }
        if url.absoluteString.lowercased().contains(".m3u8") { return true }
        switch item.platform {
        case .website, .other: return true
        default: return false
        }
    }

    // MARK: - Observation

    private func attachTimeObserver() {
        let interval = CMTime(seconds: 0.5, preferredTimescale: 600)
        timeObserver = player.addPeriodicTimeObserver(forInterval: interval, queue: .main) { [weak self] time in
            guard let self else { return }
            self.currentTime = time.seconds.isFinite ? time.seconds : 0
            self.isBuffering = false
            self.persist(force: false)
            if self.duration > 0, self.progress >= 0.9, !self.didMarkCompleted {
                self.didMarkCompleted = true
                self.item.isCompleted = true
                self.contentRepository.save()
            }
        }
    }

    /// Notification-based (not KVO) so a mid-playback stall or network drop
    /// still surfaces the error state after the initial async load succeeded.
    private func watchFailures(of playerItem: AVPlayerItem) {
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        failureObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemFailedToPlayToEndTime, object: playerItem, queue: .main
        ) { [weak self] note in
            guard let self else { return }
            let error = (note.userInfo?[AVPlayerItemFailedToPlayToEndTimeErrorKey] as? Error)?.localizedDescription
            self.phase = .failed(error ?? String(localized: "player.loadFailed", defaultValue: "This video couldn't be loaded."))
        }
    }

    /// AVPlayer pauses itself at the end of an item without telling our
    /// manually-tracked `isPlaying`, so the transport button would otherwise
    /// stay stuck showing "Pause" forever after a clip finishes.
    private func watchPlaybackEnd(of playerItem: AVPlayerItem) {
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime, object: playerItem, queue: .main
        ) { [weak self] _ in
            self?.isPlaying = false
        }
    }

    /// Notification-based stall detection; cleared by the time observer the
    /// moment playback ticks again, so it self-corrects without polling.
    private func watchBuffering(of playerItem: AVPlayerItem) {
        if let bufferingObserver { NotificationCenter.default.removeObserver(bufferingObserver) }
        bufferingObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemPlaybackStalled, object: playerItem, queue: .main
        ) { [weak self] _ in
            self?.isBuffering = true
        }
    }

    // MARK: - Persistence

    /// Throttled to ~1/sec during normal playback; `force` bypasses that for
    /// pause/seek/backgrounding, where losing the last second would be visible.
    private func persist(force: Bool) {
        guard duration > 0 else { return }
        if !force, Date.now.timeIntervalSince(lastPersistedAt) < 1 { return }
        lastPersistedAt = .now
        item.playbackPositionSeconds = currentTime
        item.playbackDurationSeconds = duration
        contentRepository.save()
    }

    func detachObservers() {
        if let timeObserver { player.removeTimeObserver(timeObserver) }
        timeObserver = nil
        loadTask?.cancel()
        if let failureObserver { NotificationCenter.default.removeObserver(failureObserver) }
        failureObserver = nil
        if let bufferingObserver { NotificationCenter.default.removeObserver(bufferingObserver) }
        bufferingObserver = nil
        if let endObserver { NotificationCenter.default.removeObserver(endObserver) }
        endObserver = nil
    }
}
