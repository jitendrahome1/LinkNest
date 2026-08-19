//
//  CollectionDetailView.swift
//

import SwiftUI
import SwiftData

struct CollectionDetailView: View {
    let collectionID: UUID

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var query = ""

    var body: some View {
        Group {
            if let collection = container.collectionRepository.collection(id: collectionID) {
                content(collection)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }

    private func items(in collection: ContentCollection) -> [ContentItem] {
        var result = collection.items.filter { !$0.isArchived }
        let q = query.trimmingCharacters(in: .whitespaces).lowercased()
        if !q.isEmpty {
            result = result.filter {
                $0.title.lowercased().contains(q) || $0.creatorName.lowercased().contains(q)
            }
        }
        return result.sorted { $0.createdAt > $1.createdAt }
    }

    private func content(_ collection: ContentCollection) -> some View {
        let filtered = items(in: collection)
        return ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    LNIconButton(systemImage: "chevron.left", tint: LNColor.primaryText,
                                 accessibilityLabel: String(localized: "a11y.back", defaultValue: "Back")) {
                        router.pop()
                    }
                    Spacer()
                }
                .padding(.horizontal, 14)

                HStack(spacing: 13) {
                    RoundedRectangle(cornerRadius: 17, style: .continuous)
                        .fill(Color(hex: collection.colorHex).opacity(0.13))
                        .frame(width: 52, height: 52)
                        .overlay {
                            Text(collection.initial)
                                .font(.system(size: 21, weight: .heavy))
                                .foregroundStyle(Color(hex: collection.colorHex))
                        }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(collection.name)
                            .font(.system(size: 21, weight: .heavy))
                            .kerning(-0.4)
                            .foregroundStyle(LNColor.primaryText)
                        Text("\(collection.activeItemCount) items")
                            .font(.system(size: 13))
                            .foregroundStyle(LNColor.secondaryText)
                    }
                }
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 12)

                LNSearchBar(placeholder: String(localized: "collection.search", defaultValue: "Search in collection"),
                            text: $query)
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 14)

                if filtered.isEmpty {
                    LNEmptyState(systemImage: "folder",
                                 title: String(localized: "collection.emptyTitle", defaultValue: "This collection is empty"),
                                 message: String(localized: "collection.emptyBody", defaultValue: "Save a link and file it here to start building this collection."))
                } else {
                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { item in
                            LNContentCardCompact(item: item, showsMenu: false,
                                                 onOpen: { open(item) },
                                                 onToggleFavorite: { toggleFavorite(item) })
                                .modifier(ItemContextMenu(item: item))
                        }
                    }
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 12)
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 44)
        }
        .background(LNColor.background)
    }

    private func open(_ item: ContentItem) {
        container.contentRepository.markViewed(item)
        router.push(.contentDetail(item.id))
    }

    private func toggleFavorite(_ item: ContentItem) {
        item.isFavorite.toggle()
        container.contentRepository.save()
    }
}
