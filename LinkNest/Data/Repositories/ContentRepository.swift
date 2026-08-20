//
//  ContentRepository.swift
//  The SwiftData implementation is the single source of truth for reads —
//  UI always renders local state instantly. Writes are mirrored to
//  Supabase in the background afterward; a mirror failure never blocks
//  or reverts the local change (offline-first).
//

import Auth
import Foundation
import Supabase
import SwiftData

@MainActor
protocol ContentRepository: AnyObject {
    func all() -> [ContentItem]
    func active() -> [ContentItem]          // not archived
    func item(id: UUID) -> ContentItem?
    func insert(_ item: ContentItem)
    func delete(_ item: ContentItem)
    func markViewed(_ item: ContentItem)
    func save()

    // Remote sync — called only by SyncService; never mirrors back out.
    func syncPull() async
    func applyRemoteUpsert(_ dto: ContentItemDTO, tagIDs: [UUID])
    func applyRemoteDelete(id: UUID)

    /// Wipes every local row without pushing deletes to Supabase. Local
    /// storage is shared by whichever account is currently signed in, so
    /// this must run on sign-out / account switch or the next user would
    /// see the previous user's library.
    func clearLocal()
}

@MainActor
final class SwiftDataContentRepository: ContentRepository {
    private let context: ModelContext
    private let remote: SupabaseContentDataSource

    init(context: ModelContext, remote: SupabaseContentDataSource) {
        self.context = context
        self.remote = remote
    }

    func all() -> [ContentItem] {
        let descriptor = FetchDescriptor<ContentItem>(sortBy: [SortDescriptor(\.createdAt, order: .reverse)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func active() -> [ContentItem] {
        let descriptor = FetchDescriptor<ContentItem>(
            predicate: #Predicate { !$0.isArchived },
            sortBy: [SortDescriptor(\.createdAt, order: .reverse)]
        )
        return (try? context.fetch(descriptor)) ?? []
    }

    func item(id: UUID) -> ContentItem? {
        let descriptor = FetchDescriptor<ContentItem>(predicate: #Predicate { $0.id == id })
        return (try? context.fetch(descriptor))?.first
    }

    func insert(_ item: ContentItem) {
        context.insert(item)
        save()
    }

    func delete(_ item: ContentItem) {
        let id = item.id
        context.delete(item)
        try? context.save()
        pushDelete(id)
    }

    func markViewed(_ item: ContentItem) {
        item.lastViewedAt = .now
        save()
    }

    /// Snapshots whatever SwiftData considers dirty right now, saves, then
    /// mirrors just those items to Supabase — so every call site that
    /// mutates an item and calls `save()` gets synced for free.
    func save() {
        let dirty = Set(context.insertedModelsArray.compactMap { $0 as? ContentItem })
            .union(context.changedModelsArray.compactMap { $0 as? ContentItem })
        try? context.save()
        dirty.forEach(pushUpsert)
    }

    // MARK: - Remote mirror

    private func pushUpsert(_ item: ContentItem) {
        guard let userID = SupabaseClientProvider.shared.auth.currentSession?.user.id else { return }
        let dto = ContentItemDTO(item: item, userID: userID)
        let tagIDs = item.tags.map(\.id)
        let itemID = item.id
        let remote = remote
        Task.detached(priority: .utility) {
            try? await remote.upsert(dto)
            try? await remote.replaceTagLinks(itemID: itemID, tagIDs: tagIDs, userID: userID)
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
        let links = (try? await remote.fetchTagLinks(userID: userID)) ?? []
        for dto in dtos {
            let tagIDs = links.filter { $0.contentItemID == dto.id }.map(\.tagID)
            applyRemoteUpsert(dto, tagIDs: tagIDs)
        }
    }

    /// Last-write-wins by `updated_at`. Never fires a push back to remote.
    func applyRemoteUpsert(_ dto: ContentItemDTO, tagIDs: [UUID]) {
        let target: ContentItem
        if let existing = item(id: dto.id) {
            guard dto.updatedAt >= existing.updatedAt else { return }
            dto.apply(to: existing)
            target = existing
        } else {
            target = dto.makeItem()
            context.insert(target)
        }

        if let collectionID = dto.collectionID {
            let descriptor = FetchDescriptor<ContentCollection>(predicate: #Predicate { $0.id == collectionID })
            target.collection = try? context.fetch(descriptor).first
        } else {
            target.collection = nil
        }

        if tagIDs.isEmpty {
            target.tags = []
        } else {
            let idSet = Set(tagIDs)
            let descriptor = FetchDescriptor<Tag>(predicate: #Predicate { idSet.contains($0.id) })
            target.tags = (try? context.fetch(descriptor)) ?? []
        }
        try? context.save()
    }

    func applyRemoteDelete(id: UUID) {
        guard let existing = item(id: id) else { return }
        context.delete(existing)
        try? context.save()
    }

    func clearLocal() {
        for item in all() { context.delete(item) }
        try? context.save()
    }
}
