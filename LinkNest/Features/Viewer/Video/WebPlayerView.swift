//
//  WebPlayerView.swift
//  Fallback for sources AVPlayer can't stream (YouTube/Instagram/Facebook/X
//  page URLs — none of them expose a direct media file). Embeds the real
//  page with WKWebView so the platform's own player can run inline, the
//  same approach read-it-later apps use for social video.
//
//  Some platforms (Facebook/Instagram in particular) accept the load and
//  report success while their anti-embedding JS renders nothing at all —
//  showing that blank page would look like a broken app, not a graceful
//  fallback. So a finished load isn't trusted at face value: shortly after
//  it fires, we check whether the page actually produced visible content;
//  only then does the caller reveal the web view. Anything else reports
//  `.blocked` so the caller can fall back to a clean "Open Original" prompt.
//

import SwiftUI
@preconcurrency import WebKit

struct WebPlayerView: UIViewRepresentable {
    let url: URL
    var onLoadStateChange: (LoadState) -> Void

    enum LoadState: Equatable { case loading, loaded, blocked, failed(String) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: url))
        context.coordinator.armTimeout()
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onLoadStateChange: onLoadStateChange) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLoadStateChange: (LoadState) -> Void
        private var hasResolved = false
        private var timeoutTask: DispatchWorkItem?

        init(onLoadStateChange: @escaping (LoadState) -> Void) {
            self.onLoadStateChange = onLoadStateChange
        }

        /// Belt-and-suspenders: if didFinish never fires (hung page, redirect
        /// loop), don't leave the user staring at a spinner forever.
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
            // Give client-side JS (both platforms here are heavy SPAs) a
            // moment to render before judging whether anything showed up.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.9) { [weak self, weak webView] in
                guard let self, let webView, !self.hasResolved else { return }
                webView.evaluateJavaScript("document.body ? document.body.innerText.trim().length : 0") { result, _ in
                    let length = (result as? Int) ?? 0
                    self.resolve(length >= 20 ? .loaded : .blocked)
                }
            }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            resolve(.failed(error.localizedDescription))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            resolve(.failed(error.localizedDescription))
        }
    }
}
