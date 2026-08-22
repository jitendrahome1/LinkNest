//
//  VideoPlayerView.swift
//  Immersive AVPlayer viewer matching the Content Viewer prototype:
//  header above a contained video card (center transport overlaid on it),
//  scrub/speed/mute/fullscreen row below in normal flow, then the
//  standard metadata + Up Next rail. Screen is always dark-themed,
//  independent of the app's light/dark setting, per the design.
//

import SwiftUI
import AVKit
import WebKit
import YouTubePlayerKit

/// Cheap, synchronous mirror of VideoSourceResolver's host/extension checks
/// (minus its network probes) — lets Up Next include saved items VideoPlayerView
/// can actually stream even when they weren't tagged `contentType == .video`
/// at save time. That tagging leans on page metadata (RemoteMetadataService),
/// which frequently can't confirm "video" for Instagram Reels, Facebook
/// videos, etc. — those land as `.post`/`.article` even though the player
/// embeds them fine, so restricting Up Next to `.video` was hiding them.
private func isVideoCandidate(_ candidate: ContentItem) -> Bool {
    if candidate.contentType == .video { return true }
    guard let url = URL(string: candidate.url), let host = url.host?.lowercased() else { return false }

    let ext = url.pathExtension.lowercased()
    if ["mp4", "mov", "m4v", "webm"].contains(ext) { return true }
    if url.absoluteString.lowercased().contains(".m3u8") { return true }

    if host.contains("youtu") || host.contains("vimeo.com") || host.contains("dailymotion.com")
        || host.contains("dai.ly") || host.contains("twitch.tv") || host.contains("streamable.com")
        || host == "v.redd.it" {
        return true
    }

    // Instagram/Facebook mix video and non-video posts, so only trust
    // permalink shapes that are unambiguously video (Reels/IGTV, Facebook
    // video/watch permalinks) rather than treating every saved link from
    // these hosts as a video.
    let path = url.path.lowercased()
    if host.contains("instagram") { return path.contains("/reel") || path.contains("/tv/") }
    if host.contains("facebook") { return path.contains("/video") || path.contains("/watch") || path.contains("/reel/") }
    return false
}

/// Shared tap/double-tap surface for every video source (AVPlayer + YouTube,
/// inline + fullscreen). A single tap toggles the transport; a double-tap on
/// the left/right half seeks ±10s with a brief icon flash — the standard
/// video-app gesture (YouTube/Netflix-style) the transport buttons alone
/// didn't provide. One SwiftUI gesture implementation for all four surfaces
/// keeps behavior consistent and is also what makes disabling the YouTube
/// webView's own touch handling safe (see YouTubeEmbedController) — this is
/// the only thing left that can receive a touch.
private struct VideoTapGestureLayer: View {
    var onToggleTransport: () -> Void
    var onSkipBack: () -> Void
    var onSkipForward: () -> Void

    private enum FlashSide { case left, right }
    @State private var flashSide: FlashSide?
    @State private var flashTask: Task<Void, Never>?

    var body: some View {
        GeometryReader { geo in
            let doubleTap = SpatialTapGesture(count: 2)
                .onEnded { value in
                    if value.location.x < geo.size.width / 2 {
                        flash(.left)
                        onSkipBack()
                    } else {
                        flash(.right)
                        onSkipForward()
                    }
                }
            let singleTap = SpatialTapGesture(count: 1)
                .onEnded { _ in onToggleTransport() }

            ZStack {
                Color.black.opacity(0.001)
                    .contentShape(Rectangle())
                    .gesture(doubleTap.exclusively(before: singleTap))

                seekFlash(systemImage: "gobackward.10", visible: flashSide == .left)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.leading, geo.size.width * 0.14)
                seekFlash(systemImage: "goforward.10", visible: flashSide == .right)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .padding(.trailing, geo.size.width * 0.14)
            }
        }
    }

    private func seekFlash(systemImage: String, visible: Bool) -> some View {
        Circle()
            .fill(.ultraThinMaterial)
            .environment(\.colorScheme, .dark)
            .frame(width: 52, height: 52)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .opacity(visible ? 1 : 0)
            .scaleEffect(visible ? 1 : 0.85)
            .allowsHitTesting(false)
    }

    private func flash(_ side: FlashSide) {
        flashTask?.cancel()
        withAnimation(.easeOut(duration: 0.15)) { flashSide = side }
        flashTask = Task {
            try? await Task.sleep(for: .seconds(0.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { flashSide = nil }
        }
    }
}

/// The generic web-page embed (Instagram/Facebook) gets a fixed, taller
/// box — see the comment on `isTallEmbedPage` below. Every other state is an
/// actual video (or a message standing in for one), so it's sized to 16:9
/// up front instead of a fixed height unrelated to the video's own aspect
/// ratio — that mismatch was letterboxing both the SwiftUI card (its own
/// `Color.black` backdrop showing through top/bottom) and, independently,
/// the underlying AVPlayer/YouTube surface itself.
private struct VideoBoxSizing: ViewModifier {
    let isTallEmbedPage: Bool

    func body(content: Content) -> some View {
        if isTallEmbedPage {
            content.frame(height: 460)
        } else {
            content.aspectRatio(16.0 / 9.0, contentMode: .fit)
        }
    }
}

/// YouTubePlayerKit doesn't expose its WKWebView publicly, so there's no
/// direct way to turn off its own touch handling (see YouTubeEmbedController
/// and VideoTapGestureLayer for why that matters). `WKWebView` itself is a
/// public system type though, so this reaches it the only way available:
/// walking up to the nearest shared ancestor with the webView and finding it
/// by type. A zero-size marker view, invisible and non-interactive itself —
/// its only job is locating its sibling once both are in the hierarchy.
private struct YouTubeWebViewInteractionDisabler: UIViewRepresentable {
    final class MarkerView: UIView {
        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard window != nil else { return }
            // The webView representable may not have inserted its view yet
            // in this same layout pass — a couple of short retries covers
            // that without polling indefinitely.
            for delay in [0, 0.1, 0.3] {
                DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                    self?.disableNearestWebView()
                }
            }
        }

        private func disableNearestWebView() {
            // Climb until a shared ancestor's subtree contains the webView —
            // exactly how many levels `.background` wraps its content at
            // isn't a contract worth depending on, so widen the search
            // outward instead of assuming a fixed depth.
            var ancestor = superview
            for _ in 0..<6 {
                guard let candidate = ancestor else { return }
                if let webView = findWebView(in: candidate) {
                    webView.isUserInteractionEnabled = false
                    return
                }
                ancestor = candidate.superview
            }
        }

        private func findWebView(in view: UIView) -> WKWebView? {
            if let webView = view as? WKWebView { return webView }
            for subview in view.subviews {
                if let match = findWebView(in: subview) { return match }
            }
            return nil
        }
    }

    func makeUIView(context: Context) -> UIView {
        let marker = MarkerView(frame: .zero)
        marker.isUserInteractionEnabled = false
        marker.isHidden = true
        return marker
    }

    func updateUIView(_ uiView: UIView, context: Context) {}
}

struct VideoPlayerView: View {
    let itemID: UUID

    @Environment(AppContainer.self) private var container
    @State private var vm: VideoPlayerViewModel?
    @State private var itemMissing = false
    /// Separate from `itemID` so picking an Up Next item can retarget the
    /// same screen in place — tapping a related video swaps the playing
    /// item without pushing a new instance of this view onto the nav stack.
    @State private var activeItemID: UUID?

    var body: some View {
        ZStack {
            LNColor.background.ignoresSafeArea()
            if let vm {
                VideoPlayerContent(vm: vm, onSelectItem: { next in
                    activeItemID = next.id
                    Task { @MainActor in
                        container.contentRepository.markViewed(next)
                    }
                })
                    // Forces a clean teardown/rebuild of the content view's
                    // own @State (fullscreen, YouTube controller, web-embed
                    // load state, PiP controller, transport visibility) when
                    // switching items, so none of it leaks from the previous
                    // video into the newly selected one.
                    .id(vm.item.id)
            } else if itemMissing {
                LNEmptyState(systemImage: "questionmark.folder",
                             title: String(localized: "detail.missing", defaultValue: "Content not found"),
                             message: String(localized: "detail.missingBody", defaultValue: "This item may have been deleted."))
            }
        }
        .task(id: activeItemID ?? itemID) {
            let targetID = activeItemID ?? itemID
            vm?.pause()
            vm?.detachObservers()
            guard let item = container.contentRepository.item(id: targetID) else {
                itemMissing = true
                vm = nil
                return
            }
            itemMissing = false
            let model = VideoPlayerViewModel(item: item, contentRepository: container.contentRepository, sourceResolver: container.videoSourceResolver)
            vm = model
            model.load()
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

private struct VideoPlayerContent: View {
    @Bindable var vm: VideoPlayerViewModel
    /// Retargets the owning VideoPlayerView at a different item in place,
    /// rather than pushing a new screen — see the comment on `activeItemID`.
    var onSelectItem: (ContentItem) -> Void

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    @State private var showTransport = true
    @State private var hideTask: Task<Void, Never>?
    @State private var isFullscreen = false
    @State private var showSpeedSheet = false
    @State private var pipController: AVPictureInPictureController?
    @State private var webLoadState: WebPlayerView.LoadState = .loading
    @State private var upNextExpanded = false
    private static let upNextCollapsedCount = 3
    /// Drives LinkNestPlayerControls/LinkNestPlayerBottomBar for a YouTube
    /// embed exactly like `vm` drives them for AVPlayer, so the visible
    /// transport UI is always LinkNest's own design, never YouTube's.
    /// Created lazily once the resolver confirms a YouTube video ID.
    @State private var ytController: YouTubeEmbedController?

    private var isYouTubeCase: Bool {
        if case .unsupportedSource(.youTube) = vm.phase { return true }
        return false
    }
    private var youTubeVideoID: String {
        if case .unsupportedSource(.youTube(let videoID)) = vm.phase { return videoID }
        return ""
    }
    private var speedBinding: Binding<Double> {
        guard isYouTubeCase, let ytController else { return $vm.speed }
        return Binding(get: { ytController.speed }, set: { ytController.speed = $0 })
    }

    private var item: ContentItem { vm.item }
    /// The generic page embed (Instagram/Facebook) grows to a taller fixed
    /// box once it's confirmed to have rendered real content, since that
    /// extra room is what makes it legible that the embed actually worked
    /// rather than silently showing a broken/blank page at the normal size
    /// — it's an arbitrary web page, not necessarily video-shaped, so a
    /// fixed height is the right call there. AVPlayer and YouTube are
    /// actual video surfaces, though, and a fixed height unrelated to the
    /// video's own aspect ratio left both the SwiftUI card AND the
    /// underlying player pillarboxing/letterboxing independently — a
    /// visible black band the card's own `Color.black` backdrop made worse.
    /// Sizing the card to 16:9 up front means there's nothing left to
    /// letterbox for the common case.
    private var isTallEmbedPage: Bool {
        if case .unsupportedSource(.embedPage) = vm.phase, webLoadState == .loaded { return true }
        return false
    }

    /// "Video · 18:24 · iOS Development" — matches the header's compact
    /// metadata line in the design.
    private var headerSubtitle: String {
        let typePart = item.duration.map { String(localized: "player.videoDuration", defaultValue: "Video · \($0)") }
            ?? String(localized: "player.videoType", defaultValue: "Video")
        let collectionPart = item.collection?.name ?? String(localized: "detail.noCollection", defaultValue: "No collection")
        return "\(typePart) · \(collectionPart)"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LinkNestViewerHeader(title: item.title,
                                     subtitle: headerSubtitle,
                                     isFavorite: item.isFavorite,
                                     onBack: { router.pop() },
                                     onFavorite: toggleCurrentFavorite,
                                     onMore: { router.sheet = .itemMenu(item.id) })
                    .padding(.top, 6)

                videoBox()
                    .padding(.top, 10)
                    .padding(.horizontal, LNSpacing.gutter)

                if case .ready = vm.phase, !vm.showResumePrompt {
                    LinkNestPlayerBottomBar(style: .flat,
                                            progress: vm.progress,
                                            positionLabel: vm.currentTime.mmss,
                                            durationLabel: vm.duration.mmss,
                                            speedLabel: LinkNestPlaybackSpeedSheet.label(for: vm.speed),
                                            isMuted: vm.isMuted,
                                            isPiPAvailable: pipController != nil,
                                            isFullscreen: false,
                                            onScrub: { vm.scrub(toFraction: $0) },
                                            onScrubEnd: vm.commitScrub,
                                            onSpeed: { showSpeedSheet = true },
                                            onToggleMute: { vm.isMuted.toggle() },
                                            onPiP: { pipController?.startPictureInPicture() },
                                            onToggleFullscreen: { isFullscreen = true })
                        .padding(.horizontal, LNSpacing.gutter)
                        .padding(.top, 14)
                } else if isYouTubeCase, webLoadState == .loaded, let ytController {
                    LinkNestPlayerBottomBar(style: .flat,
                                            progress: ytController.progress,
                                            positionLabel: ytController.currentTime.mmss,
                                            durationLabel: ytController.duration.mmss,
                                            speedLabel: LinkNestPlaybackSpeedSheet.label(for: ytController.speed),
                                            isMuted: ytController.isMuted,
                                            isPiPAvailable: false,
                                            isFullscreen: false,
                                            onScrub: { ytController.scrub(toFraction: $0) },
                                            onScrubEnd: ytController.commitScrub,
                                            onSpeed: { showSpeedSheet = true },
                                            onToggleMute: { ytController.isMuted.toggle() },
                                            onPiP: {},
                                            onToggleFullscreen: { isFullscreen = true })
                        .padding(.horizontal, LNSpacing.gutter)
                        .padding(.top, 14)
                }

                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .font(.system(size: 17, weight: .bold))
                        .lineSpacing(2)
                        .foregroundStyle(LNColor.primaryText)
                        .padding(.top, 16)
                    Text("\(item.platform.displayName) · \(item.creatorName)")
                        .font(.system(size: 13))
                        .foregroundStyle(LNColor.secondaryText)
                        .padding(.top, 5)

                    actionPills.padding(.top, 14)

                    if !upNextItems.isEmpty {
                        HStack(alignment: .firstTextBaseline) {
                            LNSectionLabel(text: String(localized: "player.upNext", defaultValue: "Up Next"))
                            Spacer()
                            if upNextItems.count > Self.upNextCollapsedCount {
                                Button(action: { withAnimation(.easeOut(duration: 0.2)) { upNextExpanded.toggle() } }) {
                                    Text(upNextExpanded
                                        ? String(localized: "action.seeLess", defaultValue: "See Less")
                                        : String(localized: "action.seeMore", defaultValue: "See More"))
                                        .font(LNFont.chip)
                                        .foregroundStyle(LNColor.accent)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .padding(.top, 24)
                        VStack(spacing: 8) {
                            ForEach(displayedUpNextItems) { next in
                                LNContentCardCompact(item: next, showsMenu: false,
                                                     onOpen: { openUpNext(next) },
                                                     onToggleFavorite: { toggleFavorite(next) })
                            }
                        }
                        .padding(.top, 9)
                    }
                }
                .padding(.horizontal, LNSpacing.gutter)
            }
            .padding(.bottom, 40)
        }
        .background(LNColor.background)
        .toolbar(.hidden, for: .navigationBar)
        // The inline screen stays mounted (SwiftUI doesn't tear down covered
        // content), so hide its now-duplicate controls from VoiceOver while
        // the fullscreen cover owns the experience.
        .accessibilityHidden(isFullscreen)
        .task(id: youTubeVideoID) {
            guard !youTubeVideoID.isEmpty, ytController == nil else { return }
            ytController = YouTubeEmbedController(videoID: youTubeVideoID)
        }
        .sheet(isPresented: $showSpeedSheet) {
            LinkNestPlaybackSpeedSheet(selected: speedBinding)
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            if isYouTubeCase, let ytController {
                YouTubeFullscreenOverlay(sourceController: ytController,
                                         showSpeedSheet: $showSpeedSheet,
                                         onExit: { isFullscreen = false })
            } else {
                FullscreenPlayerOverlay(vm: vm, pipController: $pipController,
                                        showSpeedSheet: $showSpeedSheet,
                                        onExit: { isFullscreen = false })
            }
        }
        .onChange(of: vm.isPlaying) { _, playing in
            if playing { scheduleAutoHide() } else { hideTask?.cancel() }
        }
        .onChange(of: ytController?.isPlaying) { _, playing in
            if playing == true { scheduleAutoHide() } else { hideTask?.cancel() }
        }
        .onChange(of: webLoadState) { _, state in
            guard isYouTubeCase, state == .loaded else { return }
            ytController?.play()
        }
        .onDisappear {
            hideTask?.cancel()
            vm.pause()
            vm.detachObservers()
            ytController?.pause()
        }
    }

    // MARK: - Inline video card

    /// Subtle top/bottom darkening behind the transport controls so they
    /// stay legible over any video content, bright or dark — without this,
    /// the glass buttons sit directly on raw video pixels and can read as
    /// flat/disconnected rather than an intentional overlay. Fades with the
    /// controls themselves so idle playback stays a clean, unobstructed view.
    private var controlsScrim: some View {
        LinearGradient(colors: [.black.opacity(0.32), .clear, .clear, .black.opacity(0.4)],
                       startPoint: .top, endPoint: .bottom)
            .allowsHitTesting(false)
            .opacity(showTransport ? 1 : 0)
    }

    @ViewBuilder
    private func videoBox() -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous)
                .fill(Color.black)

            if vm.phase == .ready, !isFullscreen {
                PlayerLayerView(player: vm.player, onPiPControllerReady: { pipController = $0 })
                    .clipShape(RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous))
                VideoTapGestureLayer(onToggleTransport: toggleTransport,
                                     onSkipBack: { vm.skipBack(); scheduleAutoHide() },
                                     onSkipForward: { vm.skipForward(); scheduleAutoHide() })
            }

            switch vm.phase {
            case .loading:
                LinkNestViewerLoadingView(message: String(localized: "player.loading", defaultValue: "Loading video…"),
                                          onDarkChrome: true)
            case .unsupportedSource(let kind):
                unsupportedSourceContent(kind)
            case .failed(let message):
                LinkNestViewerErrorView(title: String(localized: "player.errorTitle", defaultValue: "Playback failed"),
                                        message: message,
                                        retryTitle: String(localized: "action.retry", defaultValue: "Retry"),
                                        onRetry: vm.retry,
                                        secondaryTitle: String(localized: "detail.openOriginal", defaultValue: "Open Original"),
                                        onSecondary: openOriginal,
                                        onDarkChrome: true)
            case .ready:
                if vm.showResumePrompt {
                    resumePrompt
                } else {
                    if vm.isBuffering {
                        LinkNestViewerLoadingView(message: String(localized: "player.buffering", defaultValue: "Buffering…"),
                                                  onDarkChrome: true)
                    } else {
                        controlsScrim
                        LinkNestPlayerControls(isPlaying: vm.isPlaying,
                                               onTogglePlay: { vm.togglePlay(); scheduleAutoHide() },
                                               onSkipBack: { vm.skipBack(); scheduleAutoHide() },
                                               onSkipForward: { vm.skipForward(); scheduleAutoHide() })
                            .opacity(showTransport ? 1 : 0)
                            .allowsHitTesting(showTransport)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .modifier(VideoBoxSizing(isTallEmbedPage: isTallEmbedPage))
        .clipShape(RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.2), value: showTransport)
    }

    /// Instagram/Facebook/X page URLs don't expose a direct media file, so
    /// AVPlayer has nothing to stream — but many platforms' own web player
    /// still runs fine inline via WKWebView. A single instance stays
    /// mounted throughout (so switching UI states never reloads the page),
    /// hidden until WebPlayerView confirms it actually rendered something;
    /// platforms that block embedding (Facebook/Instagram) fall back to the
    /// same clean "Open Original" card as any other unsupported source,
    /// rather than exposing their blank, broken-looking page.
    ///
    /// YouTube is rendered separately via `youTubeEmbedContent` — see there
    /// for why it needs YouTubePlayerKit rather than this generic WebPlayerView.
    @ViewBuilder
    private func unsupportedSourceContent(_ kind: VideoPlayerViewModel.UnsupportedKind) -> some View {
        switch kind {
        case .youTube(let videoID):
            youTubeEmbedContent(videoID: videoID)
        case .embedPage(let url):
            embeddedWebPlayer(url: url)
        }
    }

    @ViewBuilder
    private func embeddedWebPlayer(url: URL) -> some View {
        ZStack {
            WebPlayerView(url: url) { state in webLoadState = state }
                .clipShape(RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous))
                .opacity(webLoadState == .loaded ? 1 : 0)
                .allowsHitTesting(webLoadState == .loaded)

            switch webLoadState {
            case .loading:
                LinkNestViewerLoadingView(message: String(localized: "player.loadingPage", defaultValue: "Loading…"),
                                          onDarkChrome: true)
            case .loaded:
                openOriginalPill
            case .blocked:
                fallbackCard(String(localized: "player.unsupportedTitle", defaultValue: "Can't play this here"),
                            String(localized: "player.unsupportedBody", defaultValue: "This link opens a page, not a direct video file, so LinkNest can't stream it inline."),
                            isPrimary: false)
            case .failed(let message):
                fallbackCard(String(localized: "player.unsupportedTitle", defaultValue: "Can't play this here"),
                            message, isPrimary: false)
            }
        }
    }

    /// YouTube's official IFrame Player via YouTubePlayerKit — a maintained,
    /// ToS-compliant wrapper (developers.google.com/youtube/iframe_api_reference),
    /// never a raw stream URL. Its native controls/fullscreen button are
    /// disabled (see YouTubeEmbedController) so LinkNestPlayerControls is
    /// the only visible transport, matching the AVPlayer `.ready` treatment
    /// instead of exposing YouTube's own small-text web-player chrome.
    @ViewBuilder
    private func youTubeEmbedContent(videoID: String) -> some View {
        ZStack {
            if let ytController {
                // The gesture layer + controls live in YouTubePlayerView's
                // own `overlay` closure — the library composes this directly
                // on top of its webView via its own `.overlay(...)`, which
                // is the mechanism it's actually built and tested around.
                // Building a competing ZStack sibling around the player
                // instead left touches able to reach YouTube's own webView
                // underneath. The webView's interaction is now disabled at
                // the source (see YouTubeEmbedController), so this overlay
                // is the only thing that can ever receive a touch.
                YouTubePlayerView(ytController.player) { _ in
                    ZStack {
                        VideoTapGestureLayer(onToggleTransport: toggleTransport,
                                             onSkipBack: { ytController.skipBack(); scheduleAutoHide() },
                                             onSkipForward: { ytController.skipForward(); scheduleAutoHide() })

                        if webLoadState == .loaded {
                            controlsScrim
                            LinkNestPlayerControls(isPlaying: ytController.isPlaying,
                                                   onTogglePlay: { ytController.togglePlay(); scheduleAutoHide() },
                                                   onSkipBack: { ytController.skipBack(); scheduleAutoHide() },
                                                   onSkipForward: { ytController.skipForward(); scheduleAutoHide() })
                                .opacity(showTransport ? 1 : 0)
                                .allowsHitTesting(showTransport)
                        }
                    }
                }
                .onReceive(ytController.player.statePublisher) { state in
                    switch state {
                    case .idle: webLoadState = .loading
                    case .ready: webLoadState = .loaded
                    case .error(let error): webLoadState = .failed(String(describing: error))
                    }
                }
                .background(YouTubeWebViewInteractionDisabler())
                .clipShape(RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous))
            }

            switch webLoadState {
            case .loading:
                LinkNestViewerLoadingView(message: String(localized: "player.loadingPage", defaultValue: "Loading…"),
                                          onDarkChrome: true)
            case .loaded:
                openOriginalPill
            case .blocked:
                fallbackCard(String(localized: "player.youtubeTitle", defaultValue: "Watch on YouTube"),
                            String(localized: "player.youtubeBody", defaultValue: "YouTube videos play in the YouTube app or Safari for the best experience."),
                            isPrimary: true)
            case .failed(let message):
                fallbackCard(String(localized: "player.youtubeTitle", defaultValue: "Watch on YouTube"),
                            message, isPrimary: true)
            }
        }
    }

    private var openOriginalPill: some View {
        VStack {
            HStack {
                Spacer()
                Button(action: openOriginal) {
                    HStack(spacing: 5) {
                        Text(String(localized: "detail.openOriginal", defaultValue: "Open Original"))
                        Image(systemName: "arrow.up.right")
                    }
                    .font(.system(size: 11.5, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 10)
                    .frame(height: 28)
                    .background(.ultraThinMaterial, in: Capsule())
                    .environment(\.colorScheme, .dark)
                }
                .buttonStyle(.plain)
                .padding(8)
            }
            Spacer()
        }
    }

    @ViewBuilder
    private func fallbackCard(_ title: String, _ message: String, isPrimary: Bool) -> some View {
        if isPrimary {
            LinkNestViewerErrorView(systemImage: "play.rectangle",
                                    title: title,
                                    message: message,
                                    retryTitle: String(localized: "detail.openOriginal", defaultValue: "Open Original"),
                                    onRetry: openOriginal,
                                    onDarkChrome: true)
        } else {
            LinkNestViewerErrorView(systemImage: "play.slash",
                                    title: title,
                                    message: message,
                                    secondaryTitle: String(localized: "detail.openOriginal", defaultValue: "Open Original"),
                                    onSecondary: openOriginal,
                                    onDarkChrome: true)
        }
    }

    private var resumePrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(.white)
            Text(String(localized: "player.continueFrom", defaultValue: "Continue from \(item.playbackPositionSeconds.mmss)?"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
            HStack(spacing: 10) {
                Button(String(localized: "player.startOver", defaultValue: "Start Over"), action: vm.startOver)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(Color.white.opacity(0.14), in: Capsule())
                Button(String(localized: "player.continue", defaultValue: "Continue"), action: vm.continueFromSaved)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(LNColor.accent, in: Capsule())
            }
        }
        .buttonStyle(.plain)
    }

    private var actionPills: some View {
        HStack(spacing: 8) {
            Button {
                item.isWatchLater.toggle()
                container.contentRepository.save()
                appState.showToast(item.isWatchLater
                    ? String(localized: "toast.watchLater", defaultValue: "Added to Watch Later")
                    : String(localized: "toast.unwatchLater", defaultValue: "Removed from Watch Later"))
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "play.circle")
                    Text(item.isWatchLater
                        ? String(localized: "save.inWatchLater", defaultValue: "In Watch Later")
                        : String(localized: "save.watchLater", defaultValue: "Watch Later"))
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(item.isWatchLater ? .white : LNColor.primaryText)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(item.isWatchLater ? LNColor.accent : LNColor.chip, in: Capsule())
            }
            .buttonStyle(.plain)

            ShareLink(item: URL(string: item.url) ?? URL(filePath: "/")) {
                HStack(spacing: 6) {
                    Image(systemName: "square.and.arrow.up")
                    Text(String(localized: "action.share", defaultValue: "Share"))
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(LNColor.primaryText)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(LNColor.chip, in: Capsule())
            }
            .buttonStyle(.plain)

            Button {
                router.sheet = .editItem(item.id)
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                    Text(String(localized: "action.details", defaultValue: "Details"))
                }
                .font(.system(size: 12.5, weight: .semibold))
                .foregroundStyle(LNColor.primaryText)
                .padding(.horizontal, 13)
                .frame(height: 34)
                .background(LNColor.chip, in: Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Up Next

    /// Any saved item the video player can actually stream counts as a
    /// candidate here, not just ones tagged `.video` — Instagram/Facebook/X
    /// saves are frequently video posts that metadata detection couldn't
    /// confirm at save time (see RemoteMetadataService), but VideoSourceResolver
    /// still knows how to embed/play them. Restricting this list to
    /// `contentType == .video` was hiding all of those from Up Next.
    private var upNextItems: [ContentItem] {
        let all = container.contentRepository.active().filter { $0.id != item.id && isVideoCandidate($0) }
        let sameCollection = all.filter { $0.collection?.id == item.collection?.id && item.collection != nil }
        let rest = all.filter { !sameCollection.contains($0) }
        return sameCollection + rest
    }

    private var displayedUpNextItems: [ContentItem] {
        upNextExpanded ? upNextItems : Array(upNextItems.prefix(Self.upNextCollapsedCount))
    }

    private func openUpNext(_ next: ContentItem) {
        onSelectItem(next)
    }

    private func toggleFavorite(_ target: ContentItem) {
        target.isFavorite.toggle()
        container.contentRepository.save()
    }

    private func toggleCurrentFavorite() {
        item.isFavorite.toggle()
        container.contentRepository.save()
        appState.showToast(item.isFavorite
            ? String(localized: "toast.favorited", defaultValue: "Added to Favorites")
            : String(localized: "toast.unfavorited", defaultValue: "Removed from Favorites"))
    }

    private func openOriginal() {
        if let url = URL(string: item.url) { openURL(url) }
    }

    // MARK: - Auto-hide (center transport only, in inline mode)

    private func toggleTransport() {
        withAnimation(.easeOut(duration: 0.2)) { showTransport.toggle() }
        let isPlaying = isYouTubeCase ? (ytController?.isPlaying ?? false) : vm.isPlaying
        if showTransport, isPlaying { scheduleAutoHide() } else { hideTask?.cancel() }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { showTransport = false }
        }
    }
}

/// True cinema-style fullscreen: video fills the screen, header + transport
/// + bottom bar all overlaid with the translucent glass treatment, and all
/// auto-hide together. Shares the same VideoPlayerViewModel (and AVPlayer),
/// so playback continues seamlessly across the transition.
private struct FullscreenPlayerOverlay: View {
    @Bindable var vm: VideoPlayerViewModel
    @Binding var pipController: AVPictureInPictureController?
    @Binding var showSpeedSheet: Bool
    var onExit: () -> Void

    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            PlayerLayerView(player: vm.player, onPiPControllerReady: { pipController = $0 })
                .ignoresSafeArea()

            VideoTapGestureLayer(onToggleTransport: toggleControls,
                                 onSkipBack: { vm.skipBack(); scheduleAutoHide() },
                                 onSkipForward: { vm.skipForward(); scheduleAutoHide() })
                .ignoresSafeArea()

            LinearGradient(colors: [.black.opacity(0.5), .clear, .black.opacity(0.6)],
                          startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(showControls ? 1 : 0)

            if vm.isBuffering {
                LinkNestViewerLoadingView(message: String(localized: "player.buffering", defaultValue: "Buffering…"), onDarkChrome: true)
            }

            VStack {
                LinkNestViewerHeader(usesDarkChrome: true, onBack: onExit)
                    .padding(.top, 8)
                    .opacity(showControls ? 1 : 0)
                    .allowsHitTesting(showControls)
                Spacer()
                if !vm.isBuffering {
                    LinkNestPlayerControls(isPlaying: vm.isPlaying,
                                           onTogglePlay: { vm.togglePlay(); scheduleAutoHide() },
                                           onSkipBack: { vm.skipBack(); scheduleAutoHide() },
                                           onSkipForward: { vm.skipForward(); scheduleAutoHide() })
                        .opacity(showControls ? 1 : 0)
                        .allowsHitTesting(showControls)
                }
                Spacer()
                LinkNestPlayerBottomBar(style: .overlay,
                                        progress: vm.progress,
                                        positionLabel: vm.currentTime.mmss,
                                        durationLabel: vm.duration.mmss,
                                        speedLabel: LinkNestPlaybackSpeedSheet.label(for: vm.speed),
                                        isMuted: vm.isMuted,
                                        isPiPAvailable: pipController != nil,
                                        isFullscreen: true,
                                        onScrub: { vm.scrub(toFraction: $0) },
                                        onScrubEnd: vm.commitScrub,
                                        onSpeed: { showSpeedSheet = true },
                                        onToggleMute: { vm.isMuted.toggle() },
                                        onPiP: { pipController?.startPictureInPicture() },
                                        onToggleFullscreen: onExit)
                    .padding(.horizontal, LNSpacing.gutter)
                    .allowsHitTesting(showControls)
                    .padding(.bottom, 14)
                    .opacity(showControls ? 1 : 0)
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $showSpeedSheet) {
            LinkNestPlaybackSpeedSheet(selected: $vm.speed)
        }
        .onAppear { scheduleAutoHide() }
    }

    private func toggleControls() {
        withAnimation(.easeOut(duration: 0.2)) { showControls.toggle() }
        if showControls, vm.isPlaying { scheduleAutoHide() } else { hideTask?.cancel() }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { showControls = false }
        }
    }
}

/// Fullscreen counterpart to the inline YouTube embed. YouTubePlayerKit's
/// `YouTubePlayerView` hands back the SAME underlying webView instance
/// every time it's constructed from a given `YouTubePlayer` (`makeUIView`
/// just returns `player.webView`) — reusing the inline controller's player
/// here directly would fight the inline view for that one UIView, since
/// both would be mounted simultaneously (SwiftUI keeps content covered by
/// a fullScreenCover mounted, not torn down) and there's no guarantee the
/// inline instance reclaims it correctly once the cover dismisses. So this
/// creates its own separate YouTubeEmbedController/player (a brief, cheap
/// reload — the same known tradeoff the hand-rolled implementation this
/// replaced already had) and seeds it from the inline controller's current
/// position/mute/speed/play-state, then reports its own final state back
/// on exit so the inline controller picks up where fullscreen left off.
private struct YouTubeFullscreenOverlay: View {
    let sourceController: YouTubeEmbedController
    @Binding var showSpeedSheet: Bool
    var onExit: () -> Void

    @State private var controller: YouTubeEmbedController
    @State private var isReady = false
    @State private var showControls = true
    @State private var hideTask: Task<Void, Never>?

    private let initialTime: Double
    private let initialIsPlaying: Bool
    private let initialIsMuted: Bool
    private let initialSpeed: Double

    init(sourceController: YouTubeEmbedController, showSpeedSheet: Binding<Bool>, onExit: @escaping () -> Void) {
        self.sourceController = sourceController
        self._showSpeedSheet = showSpeedSheet
        self.onExit = onExit
        self.initialTime = sourceController.currentTime
        self.initialIsPlaying = sourceController.isPlaying
        self.initialIsMuted = sourceController.isMuted
        self.initialSpeed = sourceController.speed
        self._controller = State(initialValue: YouTubeEmbedController(videoID: sourceController.videoID))
    }

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            // The gesture layer lives in YouTubePlayerView's own `overlay`
            // closure — see the matching comment in youTubeEmbedContent.
            // The webView's own touch interaction is disabled at the source
            // (YouTubeEmbedController), so this is the only thing that can
            // ever receive a touch here.
            YouTubePlayerView(controller.player) { _ in
                VideoTapGestureLayer(onToggleTransport: toggleControls,
                                     onSkipBack: { controller.skipBack(); scheduleAutoHide() },
                                     onSkipForward: { controller.skipForward(); scheduleAutoHide() })
            }
                .onReceive(controller.player.statePublisher) { state in
                    guard state == .ready, !isReady else { return }
                    isReady = true
                    controller.isMuted = initialIsMuted
                    controller.speed = initialSpeed
                    controller.seek(to: initialTime)
                    if initialIsPlaying { controller.play() }
                }
                .background(YouTubeWebViewInteractionDisabler())
                .ignoresSafeArea()

            if !isReady {
                LinkNestViewerLoadingView(message: String(localized: "player.loadingPage", defaultValue: "Loading…"), onDarkChrome: true)
            }

            LinearGradient(colors: [.black.opacity(0.5), .clear, .black.opacity(0.6)],
                          startPoint: .top, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)
                .opacity(showControls ? 1 : 0)

            VStack {
                LinkNestViewerHeader(usesDarkChrome: true, onBack: exitFullscreen)
                    .padding(.top, 8)
                    .opacity(showControls ? 1 : 0)
                    .allowsHitTesting(showControls)
                Spacer()
                if isReady {
                    LinkNestPlayerControls(isPlaying: controller.isPlaying,
                                           onTogglePlay: { controller.togglePlay(); scheduleAutoHide() },
                                           onSkipBack: { controller.skipBack(); scheduleAutoHide() },
                                           onSkipForward: { controller.skipForward(); scheduleAutoHide() })
                        .opacity(showControls ? 1 : 0)
                        .allowsHitTesting(showControls)
                }
                Spacer()
                LinkNestPlayerBottomBar(style: .overlay,
                                        progress: controller.progress,
                                        positionLabel: controller.currentTime.mmss,
                                        durationLabel: controller.duration.mmss,
                                        speedLabel: LinkNestPlaybackSpeedSheet.label(for: controller.speed),
                                        isMuted: controller.isMuted,
                                        isPiPAvailable: false,
                                        isFullscreen: true,
                                        onScrub: { controller.scrub(toFraction: $0) },
                                        onScrubEnd: controller.commitScrub,
                                        onSpeed: { showSpeedSheet = true },
                                        onToggleMute: { controller.isMuted.toggle() },
                                        onPiP: {},
                                        onToggleFullscreen: exitFullscreen)
                    .padding(.horizontal, LNSpacing.gutter)
                    .allowsHitTesting(showControls)
                    .padding(.bottom, 14)
                    .opacity(showControls ? 1 : 0)
            }
        }
        .statusBarHidden()
        .sheet(isPresented: $showSpeedSheet) {
            LinkNestPlaybackSpeedSheet(selected: $controller.speed)
        }
        .onAppear { scheduleAutoHide() }
        .onDisappear { controller.pause() }
    }

    private func exitFullscreen() {
        sourceController.isMuted = controller.isMuted
        sourceController.speed = controller.speed
        sourceController.seek(to: controller.currentTime)
        if controller.isPlaying { sourceController.play() } else { sourceController.pause() }
        onExit()
    }

    private func toggleControls() {
        withAnimation(.easeOut(duration: 0.2)) { showControls.toggle() }
        if showControls, controller.isPlaying { scheduleAutoHide() } else { hideTask?.cancel() }
    }

    private func scheduleAutoHide() {
        hideTask?.cancel()
        hideTask = Task {
            try? await Task.sleep(for: .seconds(3.5))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 0.25)) { showControls = false }
        }
    }
}
