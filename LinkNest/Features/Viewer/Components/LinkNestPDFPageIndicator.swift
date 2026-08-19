//
//  LinkNestPDFPageIndicator.swift
//  Page scrub bar (reusing LinkNestPlayerProgressBar's widget) plus the
//  centered "12 / 48" label, per the Content Viewer prototype.
//

import SwiftUI

struct LinkNestPDFPageIndicator: View {
    var currentPage: Int
    var totalPages: Int
    /// 0...1
    var onScrub: (Double) -> Void
    var onScrubEnd: () -> Void

    private var progress: Double {
        guard totalPages > 1 else { return 0 }
        return Double(currentPage - 1) / Double(totalPages - 1)
    }

    var body: some View {
        VStack(spacing: 3) {
            LinkNestPlayerProgressBar(progress: progress, onScrub: onScrub, onDone: onScrubEnd)
            Text(String(localized: "pdf.pageOf", defaultValue: "Page \(currentPage) of \(max(totalPages, currentPage))"))
                .font(.system(size: 11.5))
                .foregroundStyle(LNColor.secondaryText)
        }
        .accessibilityElement(children: .combine)
    }
}
