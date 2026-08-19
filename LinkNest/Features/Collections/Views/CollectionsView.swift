//
//  CollectionsView.swift
//

import SwiftUI
import SwiftData

struct CollectionsView: View {
    @Environment(AppRouter.self) private var router

    @Query(sort: \ContentCollection.sortIndex)
    private var collections: [ContentCollection]

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                HStack {
                    Text(String(localized: "collections.title", defaultValue: "Collections"))
                        .font(LNFont.screenTitle)
                        .kerning(-0.5)
                        .foregroundStyle(LNColor.primaryText)
                    Spacer()
                    LNIconButton(systemImage: "plus", tint: LNColor.accent, background: LNColor.accentSoft,
                                 accessibilityLabel: String(localized: "a11y.newCollection", defaultValue: "New Collection")) {
                        router.sheet = .newCollection
                    }
                }
                .padding(.horizontal, LNSpacing.gutter)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible())], spacing: 10) {
                    ForEach(collections) { collection in
                        LNCollectionCard(collection: collection, showsThumbnails: true) {
                            router.push(.collectionDetail(collection.id))
                        }
                    }
                }
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 16)
            }
            .padding(.top, 10)
            .padding(.bottom, 120)
        }
        .background(LNColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }
}
