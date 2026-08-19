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

struct VideoPlayerView: View {
    let itemID: UUID

    @Environment(AppContainer.self) private var container
    @State private var vm: VideoPlayerViewModel?
    @State private var itemMissing = false

    var body: some View {
        ZStack {
            LNColor.background.ignoresSafeArea()
            if let vm {
                VideoPlayerContent(vm: vm)
            } else if itemMissing {
                LNEmptyState(systemImage: "questionmark.folder",
                             title: String(localized: "detail.missing", defaultValue: "Content not found"),
                             message: String(localized: "detail.missingBody", defaultValue: "This item may have been deleted."))
            }
        }
        .task {
            guard vm == nil else { return }
            guard let item = container.contentRepository.item(id: itemID) else {
                itemMissing = true
                return
            }
            let model = VideoPlayerViewModel(item: item, contentRepository: container.contentRepository)
            vm = model
            model.load()
        }
        .toolbar(.hidden, for: .navigationBar)
        .preferredColorScheme(.dark)
    }
}

private struct VideoPlayerContent: View {
    @Bindable var vm: VideoPlayerViewModel

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

    private var item: ContentItem { vm.item }
    /// The native player is a small contained card; the web fallback needs
    /// real room since the user is interacting with the actual platform page.
    private var videoBoxHeight: CGFloat { vm.phase == .unsupportedSource ? 460 : 230 }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                LinkNestViewerHeader(isFavorite: item.isFavorite,
                                     onBack: { router.pop() },
                                     onFavorite: toggleCurrentFavorite,
                                     onMore: { router.sheet = .itemMenu(item.id) })
                    .padding(.top, 6)

                videoBox(height: videoBoxHeight)
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
                        LNSectionLabel(text: String(localized: "player.upNext", defaultValue: "Up Next"))
                            .padding(.top, 24)
                        VStack(spacing: 8) {
                            ForEach(upNextItems) { next in
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
        .sheet(isPresented: $showSpeedSheet) {
            LinkNestPlaybackSpeedSheet(selected: $vm.speed)
        }
        .fullScreenCover(isPresented: $isFullscreen) {
            FullscreenPlayerOverlay(vm: vm, pipController: $pipController,
                                    showSpeedSheet: $showSpeedSheet,
                                    onExit: { isFullscreen = false })
        }
        .onChange(of: vm.isPlaying) { _, playing in
            if playing { scheduleAutoHide() } else { hideTask?.cancel() }
        }
        .onDisappear {
            hideTask?.cancel()
            vm.pause()
            vm.detachObservers()
        }
    }

    // MARK: - Inline video card

    @ViewBuilder
    private func videoBox(height: CGFloat) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous)
                .fill(Color.black)

            if vm.phase == .ready, !isFullscreen {
                PlayerLayerView(player: vm.player,
                                onTap: toggleTransport,
                                onPiPControllerReady: { pipController = $0 })
                    .clipShape(RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous))
            }

            switch vm.phase {
            case .loading:
                LinkNestViewerLoadingView(message: String(localized: "player.loading", defaultValue: "Loading video…"),
                                          onDarkChrome: true)
            case .unsupportedSource:
                unsupportedSourceContent
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
        .frame(height: height)
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous))
        .contentShape(Rectangle())
        .animation(.easeOut(duration: 0.2), value: showTransport)
    }

    /// YouTube/Instagram/Facebook/X page URLs don't expose a direct media
    /// file, so AVPlayer has nothing to stream — but the platform's own web
    /// player can still run inline via WKWebView, same as opening the link
    /// in Safari but without leaving the app.
    @ViewBuilder
    private var unsupportedSourceContent: some View {
        if let url = URL(string: item.url) {
            WebPlayerView(url: url) { state in webLoadState = state }
                .clipShape(RoundedRectangle(cornerRadius: LNRadius.hero, style: .continuous))

            if case .loading = webLoadState {
                LinkNestViewerLoadingView(message: String(localized: "player.loadingPage", defaultValue: "Loading…"),
                                          onDarkChrome: true)
            }
            if case .failed(let message) = webLoadState {
                LinkNestViewerErrorView(systemImage: "play.slash",
                                        title: String(localized: "player.unsupportedTitle", defaultValue: "Can't play this here"),
                                        message: message,
                                        secondaryTitle: String(localized: "detail.openOriginal", defaultValue: "Open Original"),
                                        onSecondary: openOriginal,
                                        onDarkChrome: true)
            }

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
        } else {
            LinkNestViewerErrorView(systemImage: "play.slash",
                                    title: String(localized: "player.unsupportedTitle", defaultValue: "Can't play this here"),
                                    message: String(localized: "player.invalidURL", defaultValue: "This link isn't a valid video URL."),
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

    private var upNextItems: [ContentItem] {
        let all = container.contentRepository.active().filter { $0.id != item.id && $0.contentType == .video }
        let sameCollection = all.filter { $0.collection?.id == item.collection?.id && item.collection != nil }
        let rest = all.filter { !sameCollection.contains($0) }
        return Array((sameCollection + rest).prefix(3))
    }

    private func openUpNext(_ next: ContentItem) {
        container.contentRepository.markViewed(next)
        router.push(.viewer(for: next))
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
        if showTransport, vm.isPlaying { scheduleAutoHide() } else { hideTask?.cancel() }
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

            PlayerLayerView(player: vm.player, onTap: toggleControls, onPiPControllerReady: { pipController = $0 })
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
