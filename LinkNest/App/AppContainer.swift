//
//  AppContainer.swift
//  Composition root — builds the model container, repositories,
//  services and use cases, and hands them to features via Environment.
//

import Foundation
import SwiftData
import Observation

@Observable
@MainActor
final class AppContainer {
    let modelContainer: ModelContainer
    let appState: AppState
    let router: AppRouter

    // Repositories
    let contentRepository: any ContentRepository
    let collectionRepository: any CollectionRepository
    let tagRepository: any TagRepository

    // Services
    let metadataService: any MetadataService
    let authService: any AuthenticationService
    let searchService: SearchService
    let syncService: any SyncService
    let aiService: any AIService

    // Cross-feature coordination
    /// Set by Home quick actions; consumed by SavedView on appear.
    var savedFilterRequest: SavedFilterRequest?
    /// The live Saved view model, so the Filter/Sort sheets edit the same state.
    weak var savedViewModel: SavedViewModel?

    // Use cases
    let saveContent: SaveContentUseCase
    let deleteContent: DeleteContentUseCase
    let filterContent: FilterContentUseCase
    let createCollection: CreateCollectionUseCase
    let fetchMetadata: FetchContentMetadataUseCase

    init(inMemory: Bool = false) {
        modelContainer = ModelContainerProvider.make(inMemory: inMemory)
        appState = AppState()
        router = AppRouter()

        let context = modelContainer.mainContext
        contentRepository = SwiftDataContentRepository(context: context)
        collectionRepository = SwiftDataCollectionRepository(context: context)
        tagRepository = SwiftDataTagRepository(context: context)

        metadataService = RemoteMetadataService(fallback: MockMetadataService())
        authService = MockAuthenticationService(keychain: KeychainManager())
        searchService = SearchService(content: contentRepository,
                                      collections: collectionRepository,
                                      tags: tagRepository)
        syncService = NoopSyncService()
        aiService = UnavailableAIService()

        saveContent = SaveContentUseCase(content: contentRepository, tags: tagRepository)
        deleteContent = DeleteContentUseCase(content: contentRepository)
        filterContent = FilterContentUseCase()
        createCollection = CreateCollectionUseCase(collections: collectionRepository)
        fetchMetadata = FetchContentMetadataUseCase(metadata: metadataService)

        MockSeeder.seedIfNeeded(context: context)
        HTMLEntityRepair.run(content: contentRepository)
    }

    /// In-memory container for previews and tests.
    static func preview() -> AppContainer { AppContainer(inMemory: true) }
}
