//
//  LinkNestViewerLoadingView.swift
//  Shared loading/buffering indicator for the video and PDF viewers.
//

import SwiftUI

struct LinkNestViewerLoadingView: View {
    var message: String
    /// Video's dark chrome needs a white spinner/text; the PDF reader
    /// sits on the app's normal theme-aware background.
    var onDarkChrome = false

    var body: some View {
        VStack(spacing: 10) {
            ProgressView()
                .tint(onDarkChrome ? .white : LNColor.accent)
            Text(message)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(onDarkChrome ? .white.opacity(0.75) : LNColor.secondaryText)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .accessibilityElement(children: .combine)
    }
}
