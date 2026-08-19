//
//  WebPlayerView.swift
//  Fallback for sources AVPlayer can't stream (YouTube/Instagram/Facebook/X
//  page URLs — none of them expose a direct media file). Embeds the real
//  page with WKWebView so the platform's own player can run inline, the
//  same approach read-it-later apps use for social video.
//

import SwiftUI
@preconcurrency import WebKit

struct WebPlayerView: UIViewRepresentable {
    let url: URL
    var onLoadStateChange: (LoadState) -> Void

    enum LoadState { case loading, loaded, failed(String) }

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.allowsInlineMediaPlayback = true
        config.mediaTypesRequiringUserActionForPlayback = []
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.navigationDelegate = context.coordinator
        webView.customUserAgent = "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator(onLoadStateChange: onLoadStateChange) }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var onLoadStateChange: (LoadState) -> Void

        init(onLoadStateChange: @escaping (LoadState) -> Void) {
            self.onLoadStateChange = onLoadStateChange
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            onLoadStateChange(.loaded)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            onLoadStateChange(.failed(error.localizedDescription))
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            onLoadStateChange(.failed(error.localizedDescription))
        }
    }
}
