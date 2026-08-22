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
    var selectedTags: Set<String> = []
    var notes = ""
    var isFavorite = false
    var isWatchLater = false

    /// Inline "+ New Tag" field state, shown in place of the chip while typing.
    var isAddingTag = false
    var newTagName = ""

    private let fetchMetadata: FetchContentMetadataUseCase
    private let saveContent: SaveContentUseCase
    private let collections: any CollectionRepository
    private let tags: any TagRepository
    var onError: ((String) -> Void)?

    init(fetchMetadata: FetchContentMetadataUseCase,
         saveContent: SaveContentUseCase,
         collections: any CollectionRepository,
         tags: any TagRepository,
         prefillURL: String?) {
        self.fetchMetadata = fetchMetadata
        self.saveContent = saveContent
        self.collections = collections
        self.tags = tags
        if let prefillURL { url = prefillURL }
        selectedCollectionID = collections.all().first?.id
    }

    var allCollections: [ContentCollection] { collections.all() }

    /// Most-used tags first so the ones you're likely to reach for surface early.
    var allTags: [Tag] {
        tags.all().sorted {
            $0.usageCount != $1.usageCount
                ? $0.usageCount > $1.usageCount
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

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

    func beginAddTag() {
        newTagName = ""
        isAddingTag = true
    }

    func cancelAddTag() {
        newTagName = ""
        isAddingTag = false
    }

    /// Creates (or reuses) the typed tag and auto-attaches it to this save.
    func commitNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard !name.isEmpty else {
            onError?(String(localized: "tags.typeName", defaultValue: "Type a tag name first"))
            return
        }
        let tag = tags.findOrCreate(named: name)
        selectedTags.insert(tag.name)
        newTagName = ""
        isAddingTag = false
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
