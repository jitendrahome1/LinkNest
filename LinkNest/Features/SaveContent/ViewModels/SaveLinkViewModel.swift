//
//  SaveLinkViewModel.swift
//

import Foundation
import Observation

@Observable
@MainActor
final class SaveLinkViewModel {
    enum FetchState: Equatable { case idle, loading, ready(LinkMetadata) }

    var url = ""
    var state: FetchState = .idle
    var selectedCollectionID: UUID?
    var selectedTags: Set<String> = ["SwiftUI"]
    var notes = ""
    var isFavorite = false
    var isWatchLater = false

    static let suggestedTags = ["SwiftUI", "Swift", "AI", "Architecture", "Design", "Career", "Finance", "Learning"]

    private let fetchMetadata: FetchContentMetadataUseCase
    private let saveContent: SaveContentUseCase
    private let collections: any CollectionRepository
    var onError: ((String) -> Void)?

    init(fetchMetadata: FetchContentMetadataUseCase,
         saveContent: SaveContentUseCase,
         collections: any CollectionRepository,
         prefillURL: String?) {
        self.fetchMetadata = fetchMetadata
        self.saveContent = saveContent
        self.collections = collections
        if let prefillURL { url = prefillURL }
        selectedCollectionID = collections.all().first?.id
    }

    var allCollections: [ContentCollection] { collections.all() }

    func pasteExample() {
        url = "https://www.youtube.com/watch?v=8kZq3xB"
        state = .idle
    }

    func fetch() {
        let trimmed = url.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else {
            onError?(String(localized: "save.noLink", defaultValue: "Paste or enter a link first"))
            return
        }
        state = .loading
        Task {
            do {
                let metadata = try await fetchMetadata(url: trimmed)
                state = .ready(metadata)
            } catch {
                state = .idle
                onError?(error.localizedDescription)
            }
        }
    }

    func toggleTag(_ tag: String) {
        if selectedTags.contains(tag) { selectedTags.remove(tag) } else { selectedTags.insert(tag) }
    }

    /// Returns the saved item, or nil if metadata isn't ready.
    func save() -> ContentItem? {
        guard case .ready(let metadata) = state else { return nil }
        let collection = selectedCollectionID.flatMap { id in allCollections.first { $0.id == id } }
        return saveContent(.init(url: url,
                                 metadata: metadata,
                                 collection: collection,
                                 tagNames: Array(selectedTags.prefix(3)),
                                 notes: notes,
                                 isFavorite: isFavorite,
                                 isWatchLater: isWatchLater))
    }
}
