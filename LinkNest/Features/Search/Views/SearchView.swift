//
//  SearchView.swift
//  Global search: recents + suggestions when idle; results grouped into
//  Collections / Tags / Content when typing.
//

import SwiftUI
import SwiftData

struct SearchView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppRouter.self) private var router

    @Query(sort: \SavedSearch.createdAt, order: .reverse)
    private var recentSearches: [SavedSearch]

    @State private var query = ""

    private let suggestions = ["SwiftUI", "AI", "Design", "Career"]

    private var results: SearchResults { container.searchService.search(query) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    LNSearchBar(placeholder: String(localized: "search.placeholder", defaultValue: "Search titles, tags, creators…"),
                                text: $query, isFocusedOnAppear: true)
                    Button(String(localized: "search.cancel", defaultValue: "Cancel")) { router.pop() }
                        .font(.system(size: 15, weight: .medium))
                        .foregroundStyle(LNColor.accent)
                        .buttonStyle(.plain)
                }
                .padding(.horizontal, LNSpacing.gutter)

                if query.trimmingCharacters(in: .whitespaces).isEmpty {
                    idleContent
                } else {
                    resultsContent
                }
            }
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .background(LNColor.background)
        .toolbar(.hidden, for: .navigationBar)
    }

    private var idleContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            LNSectionLabel(text: String(localized: "search.recent", defaultValue: "Recent"))
                .padding(.top, 20)
            VStack(spacing: 0) {
                ForEach(recentSearches.prefix(3)) { search in
                    Button {
                        query = search.query
                    } label: {
                        HStack(spacing: 10) {
                            Image(systemName: "clock")
                                .font(.system(size: 14))
                                .foregroundStyle(LNColor.tertiaryText)
                            Text(search.query)
                                .font(LNFont.body)
                                .foregroundStyle(LNColor.primaryText)
                            Spacer()
                        }
                        .padding(.vertical, 11)
                        .overlay(alignment: .bottom) {
                            Rectangle().fill(LNColor.separator).frame(height: 0.5)
                        }
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 4)

            LNSectionLabel(text: String(localized: "search.suggested", defaultValue: "Suggested"))
                .padding(.top, 24)
            FlowLayout(spacing: 8) {
                ForEach(suggestions, id: \.self) { suggestion in
                    Button { query = suggestion } label: {
                        Text(suggestion)
                            .font(LNFont.chip)
                            .foregroundStyle(LNColor.accent)
                            .padding(.horizontal, 13)
                            .frame(height: 32)
                            .background(LNColor.accentSoft, in: Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.top, 10)
        }
        .padding(.horizontal, LNSpacing.gutter)
    }

    private var resultsContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            if results.isEmpty {
                LNEmptyState(systemImage: "magnifyingglass",
                             title: String(localized: "search.noResultsTitle", defaultValue: "No results for “\(query)”"),
                             message: String(localized: "search.noResultsBody", defaultValue: "Check the spelling, or try a broader term like a tag or creator name."))
            } else {
                if !results.collections.isEmpty {
                    LNSectionLabel(text: String(localized: "search.collections", defaultValue: "Collections"))
                        .padding(.top, 16)
                    ForEach(results.collections) { collection in
                        Button {
                            router.push(.collectionDetail(collection.id))
                        } label: {
                            HStack(spacing: 11) {
                                RoundedRectangle(cornerRadius: 11, style: .continuous)
                                    .fill(Color(hex: collection.colorHex).opacity(0.13))
                                    .frame(width: 34, height: 34)
                                    .overlay {
                                        Text(collection.initial)
                                            .font(.system(size: 14, weight: .heavy))
                                            .foregroundStyle(Color(hex: collection.colorHex))
                                    }
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(collection.name)
                                        .font(.system(size: 14.5, weight: .semibold))
                                        .foregroundStyle(LNColor.primaryText)
                                    Text("\(collection.activeItemCount) items")
                                        .font(LNFont.meta)
                                        .foregroundStyle(LNColor.secondaryText)
                                }
                                Spacer()
                            }
                            .padding(.vertical, 9)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if !results.tags.isEmpty {
                    LNSectionLabel(text: String(localized: "search.tags", defaultValue: "Tags"))
                        .padding(.top, 12)
                    FlowLayout(spacing: 8) {
                        ForEach(results.tags) { tag in
                            Button { query = tag.name } label: {
                                Text("#\(tag.name)")
                                    .font(LNFont.chip)
                                    .foregroundStyle(LNColor.accent)
                                    .padding(.horizontal, 12)
                                    .frame(height: 30)
                                    .background(LNColor.accentSoft, in: Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top, 8)
                }
                if !results.items.isEmpty {
                    LNSectionLabel(text: String(localized: "search.content", defaultValue: "Content"))
                        .padding(.top, 16)
                    LazyVStack(spacing: 8) {
                        ForEach(results.items) { item in
                            LNContentCardCompact(item: item, showsMenu: false,
                                                 onOpen: { open(item) },
                                                 onToggleFavorite: {
                                                     item.isFavorite.toggle()
                                                     container.contentRepository.save()
                                                 })
                        }
                    }
                    .padding(.top, 8)
                }
            }
        }
        .padding(.horizontal, LNSpacing.gutter)
    }

    private func open(_ item: ContentItem) {
        router.push(.viewer(for: item))
        Task { @MainActor in
            container.contentRepository.markViewed(item)
        }
    }
}
