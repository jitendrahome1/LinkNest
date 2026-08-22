//
//  CollectionRepository.swift
//

import Auth
import Foundation
import Supabase
import SwiftData

@MainActor
protocol CollectionRepository: AnyObject {
    func all() -> [ContentCollection]
    func collection(id: UUID) -> ContentCollection?
    func insert(_ collection: ContentCollection)
    func update(_ collection: ContentCollection, name: String, colorHex: UInt32)
    func delete(_ collection: ContentCollection)

    func syncPull() async
    func applyRemoteUpsert(_ dto: ContentCollectionDTO)
    func applyRemoteDelete(id: UUID)
    func clearLocal()
}

@MainActor
final class SwiftDataCollectionRepository: CollectionRepository {
    private let context: ModelContext
    private let remote: SupabaseCollectionDataSource

    init(context: ModelContext, remote: SupabaseCollectionDataSource) {
        self.context = context
        self.remote = remote
    }

    func all() -> [ContentCollection] {
        let descriptor = FetchDescriptor<ContentCollection>(sortBy: [SortDescriptor(\.sortIndex)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func collection(id: UUID) -> ContentCollection? {
        let descriptor = FetchDescriptor<ContentCollection>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    func insert(_ collection: ContentCollection) {
        collection.sortIndex = (all().map(\.sortIndex).max() ?? -1) + 1
        context.insert(collection)
        try? context.save()
        pushUpsert(collection)
    }

    func update(_ collection: ContentCollection, name: String, colorHex: UInt32) {
        collection.name = name
        collection.colorHex = colorHex
        try? context.save()
        pushUpsert(collection)
    }

    func delete(_ collection: ContentCollection) {
        let id = collection.id
        context.delete(collection)
        try? context.save()
        pushDelete(id)
    }

    // MARK: - Remote mirror

    private func pushUpsert(_ collection: ContentCollection) {
        guard let userID = SupabaseClientProvider.shared.auth.currentSession?.user.id else { return }
        let dto = ContentCollectionDTO(collection: collection, userID: userID)
        let remote = remote
        Task.detached(priority: .utility) {
            try? await remote.upsert(dto)
        }
    }

    private func pushDelete(_ id: UUID) {
        guard SupabaseClientProvider.shared.auth.currentSession != nil else { return }
        let remote = remote
        Task.detached(priority: .utility) {
            try? await remote.delete(id: id)
        }
    }

    // MARK: - Remote → local merge

    func syncPull() async {
        guard let userID = SupabaseClientProvider.shared.auth.currentSession?.user.id else { return }
        guard let dtos = try? await remote.fetchAll(userID: userID) else { return }
        dtos.forEach(applyRemoteUpsert)
    }

    func applyRemoteUpsert(_ dto: ContentCollectionDTO) {
        if let existing = collection(id: dto.id) {
            dto.apply(to: existing)
        } else {
            context.insert(dto.makeCollection())
        }
        try? context.save()
    }

    func applyRemoteDelete(id: UUID) {
        guard let existing = collection(id: id) else { return }
        context.delete(existing)
        try? context.save()
    }

    func clearLocal() {
        for collection in all() { context.delete(collection) }
        try? context.save()
    }
}
