//
//  WebPlayerView.swift
//  Fallback for sources AVPlayer can't stream directly. Two flavors:
//
//  `.page(url)` — Instagram/Facebook/X/LinkedIn/generic page URLs, none of
//  which expose a direct media file. Embeds the real page with WKWebView so
//  the platform's own player can run inline, the same approach read-it-later
//  apps use for social video. Some platforms (Facebook/Instagram in
//  particular) accept the load and report success while their
//  anti-embedding JS renders nothing at all — showing that blank page would
//  look like a broken app, not a graceful fallback. So a finished load
//  isn't trusted at face value: shortly after it fires, we check whether
//  the page actually produced visible content; only then does the caller
//  reveal the web view. Anything else reports `.blocked` so the caller can
//  fall back to a clean "Open Original" prompt.
//
//  `.youTube(videoID:)` — YouTube's own official IFrame Player, embedded
//  via their documented public JS API (developers.google.com/youtube/iframe_api_reference).
//  Never extracts or plays a raw stream URL — this is always YouTube's own
//  player, just with its native on-screen controls hidden (`controls:0`)
//  so LinkNest's own LinkNestPlayerControls/LinkNestPlayerBottomBar can
//  drive it instead, keeping the visible UI consistent with the rest of
//  the app rather than exposing YouTube's own small-text web-player chrome.
//  The wrapper page loads the official `YT.Player` JS API (not the raw
//  postMessage protocol) and relays its onReady/onStateChange events plus a
//  periodic currentTime/duration tick to native via a WKScriptMessageHandler
//  bridge — see YouTubeEmbedController, which turns those messages into
//  the same @Observable transport state AVPlayer sources already expose.
//
//  A direct top-level navigation to youtube.com/embed/{id} (no JS API)
//  fails with YouTube's own Error 153 ("video player configuration
//  error"), because the IFrame Player expects a parent frame with a real
//  origin (a documented WebKit Referer-propagation quirk — WebKit bug
//  169846 — trips YouTube's embed-origin check on a bare top-level load).
//  `new YT.Player(...)`'s `origin` playerVar is YouTube's own documented
//  fix for exactly this case, and is what actually defeats Error 153 here.
//

import SwiftUI
@preconcurrency import WebKit

struct WebPlayerView: UIViewRepresentable {
    enum Source: Equatable {
        case page(URL)
        case youTube(videoID: String)
    }

    let source: Source
    /// Only meaningful for `.youTube` — nil for `.page`.
    var youTubeController: YouTubeEmbedController?
    /// Only meaningful for `.youTube` — nil for `.page`. A native
    /// UITapGestureRecognizer on the webView itself, same pattern as
    /// PlayerLayerView's onTap for AVPlayer — a SwiftUI-level .onTapGesture
    /// layered over a UIViewRepresentable doesn't reliably win against the
    /// wrapped UIKit view's own touch handling.
    var onTap: (() -> Void)? = nil
    var onLoadStateChange: (LoadState) -> Void

    enum LoadState: Equatable { case loading, loaded, blocked, failed(String) }

    /// Only needs to be a consistent, real-looking https:// origin — never
    /// dereferenced by anything, just compared against by YouTube's embed
    /// check (see the file-level comment above).
    private static let embedOrigin = "https://linknest.app"
    private static let bridgeHandlerName = "ytBridge"

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        if case .youTube = source {
            config.userContentController.add(context.coordinator, name: Self.bridgeHandlerName)
        }
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        switch source {
        case .page(let url):
            webView.load(URLRequest(url: url))
        case .youTube(let videoID):
            youTubeController?.webView = webView
            webView.loadHTMLString(Self.youTubeWrapperHTML(videoID: videoID), baseURL: URL(string: Self.embedOrigin))
            // WKWebView's content view installs its own gesture recognizers
            // (scroll/zoom/long-press) that can otherwise swallow a plain
            // added recognizer before it fires — the delegate callback below
            // explicitly allows both to recognize together.
            let tap = UITapGestureRecognizer(target: context.coordinator, action: #selector(Coordinator.handleTap))
            tap.delegate = context.coordinator
            webView.addGestureRecognizer(tap)
        }
        context.coordinator.armTimeout()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        context.coordinator.onTap = onTap
    }

    func makeCoordinator() -> Coordinator { Coordinator(source: source, youTubeController: youTubeController, onTap: onTap, onLoadStateChange: onLoadStateChange) }

    private static func youTubeWrapperHTML(videoID: String) -> String {
        """
        <!DOCTYPE html><html>
        <head><style>
          html, body { margin:0; padding:0; width:100%; height:100%; background:#000; overflow:hidden; }
          #ytplayer { width:100%; height:100%; }
        </style></head>
        <body>
        <div id="ytplayer"></div>
        <script>
          var player;
          function post(obj) {
            if (window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.\(bridgeHandlerName)) {
              window.webkit.messageHandlers.\(bridgeHandlerName).postMessage(obj);
            }
          }
          function onYouTubeIframeAPIReady() {
            player = new YT.Player('ytplayer', {
              videoId: '\(videoID)',
              playerVars: { playsinline: 1, controls: 0, modestbranding: 1, rel: 0, disablekb: 1, fs: 0, iv_load_policy: 3, origin: '\(embedOrigin)' },
              events: {
                onReady: function() { post({type:'ready'}); },
                onStateChange: function(e) { post({type:'stateChange', state:e.data}); },
                onError: function(e) { post({type:'error', code:e.data}); }
              }
            });
          }
          setInterval(function() {
            if (player && player.getCurrentTime) {
              try { post({type:'tick', currentTime: player.getCurrentTime(), duration: player.getDuration()}); } catch (e) {}
            }
          }, 400);
        </script>
        <script src="https://www.youtube.com/iframe_api"></script>
        </body></html>
        """
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler, UIGestureRecognizerDelegate {
        private let source: Source
        private let youTubeController: YouTubeEmbedController?
        var onTap: (() -> Void)?
        var onLoadStateChange: (LoadState) -> Void
        private var hasResolved = false
        private var timeoutTask: DispatchWorkItem?

        @objc func handleTap() { onTap?() }

        func gestureRecognizer(_ gestureRecognizer: UIGestureRecognizer, shouldRecognizeSimultaneouslyWith otherGestureRecognizer: UIGestureRecognizer) -> Bool { true }

        init(source: Source, youTubeController: YouTubeEmbedController?, onTap: (() -> Void)?, onLoadStateChange: @escaping (LoadState) -> Void) {
            self.onTap = onTap
            self.source = source
            self.youTubeController = youTubeController
            self.onLoadStateChange = onLoadStateChange
        }

        /// Belt-and-suspenders: if the page/player never resolves (hung
        /// load, redirect loop, YT.Player never fires onReady), don't leave
        /// the user staring at a spinner forever.
        func armTimeout() {
            let task = DispatchWorkItem { [weak self] in self?.resolve(.blocked) }
            timeoutTask = task
            DispatchQueue.main.asyncAfter(deadline: .now() + 8, execute: task)
        }

        private func resolve(_ state: LoadState) {
            guard !hasResolved else { return }
            hasResolved = true
            timeoutTask?.cancel()
            onLoadStateChange(state)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            switch source {
            case .page:
                // Give client-side JS (both platforms here are heavy SPAs) a
                // moment to render before judging whether anything showed up.
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self, weak webView] in
                    guard let self, let webView, !self.hasResolved else { return }
                    webView.evaluateJavaScript("document.body ? document.body.innerText.trim().length : 0") { result, _ in
                        let length = (result as? Int) ?? 0
                        self.resolve(length >= 20 ? .loaded : .blocked)
                    }
                }
            case .youTube:
                // The wrapper shell finishing navigation only means the
                // empty page loaded — the actual YT.Player still has to
                // initialize asynchronously (its own script tag, its own
                // network round trip). Wait for its onReady bridge message
                // instead of guessing a fixed delay; see userContentController(_:didReceive:).
                break
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            resolve(.failed(error.localizedDescription))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            resolve(.failed(error.localizedDescription))
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any] else { return }
            youTubeController?.handle(body)
            switch body["type"] as? String {
            case "ready":
                resolve(.loaded)
                youTubeController?.resumeAfterReady()
            case "error":
                resolve(.failed(String(localized: "player.loadFailed", defaultValue: "This video couldn't be loaded.")))
            default: break
            }
        }
    }
}
