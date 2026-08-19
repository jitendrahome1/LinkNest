//
//  LinkNestPDFToolbar.swift
//  PDF reader's top bar: same LinkNestViewerHeader as every other viewer,
//  extended with the search entry point that only the reader needs.
//

import SwiftUI

struct LinkNestPDFToolbar: View {
    var title: String
    var subtitle: String
    var onBack: () -> Void
    var onSearch: () -> Void
    var onMore: () -> Void

    var body: some View {
        LinkNestViewerHeader(title: title, subtitle: subtitle,
                             onBack: onBack, onSearch: onSearch, onMore: onMore)
    }
}
