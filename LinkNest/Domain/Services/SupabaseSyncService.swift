//
//  SupabaseSyncService.swift
//  Two halves: syncNow() does a one-shot pull-and-merge (collections and
//  tags before content, so content_items' foreign keys resolve locally),
//  then opens Realtime channels so changes from other devices land live.
//  Pushing local changes to Supabase is the repositories' job, not this
//  service's — see the `pushUpsert`/`pushDelete` mirrors in each repo.
//

import Foundation
import Supabase

@MainActor
final class SupabaseSyncService: SyncService, @unchecked Sendable {
    private(set) var status: SyncStatus = .idle

    private let content: any ContentRepository
    private let collections: any CollectionRepository
    private let tags: any TagRepository
    private let contentData = SupabaseContentDataSource()
    private var client: SupabaseClient { SupabaseClientProvider.shared }

    private var realtimeChannels: [RealtimeChannelV2] = []
    private var subscribedUserID: UUID?

    init(content: any ContentRepository, collections: any CollectionRepository, tags: any TagRepository) {
        self.content = content
        self.collections = collections
        self.tags = tags
    }

    private static let lastSyncedUserIDKey = "linknest.lastSyncedUserID"

    func syncNow() async {
        guard let userID = client.auth.currentSession?.user.id else {
            status = .idle
            return
        }
        status = .syncing

        // Local storage is shared by whoever's signed in on this device. If
        // the last account synced here isn't this one — e.g. the app was
        // force-quit instead of signed out — clear the leftover library
        // before pulling, so accounts never bleed into each other.
        let defaults = UserDefaults.standard
        let lastUserIDString = defaults.string(forKey: Self.lastSyncedUserIDKey)
        if lastUserIDString != userID.uuidString {
            content.clearLocal()
            collections.clearLocal()
            tags.clearLocal()
            defaults.set(userID.uuidString, forKey: Self.lastSyncedUserIDKey)
        }

        await collections.syncPull()
        await tags.syncPull()
        await content.syncPull()

        // Self-healing: if this account still has zero collections after a
        // real pull from Supabase — whether it's a fresh sign-up or a sign-up
        // whose one-time seed got skipped earlier — give it the defaults now.
        SeedDefaultCollectionsUseCase(collections: collections)()

        await subscribeRealtime(userID: userID)
        status = .upToDate(.now)
    }

    /// Called on sign-out so the next sign-in starts clean.
    func stop() async {
        await teardownRealtime()
        status = .idle
    }

    // MARK: - Realtime

    private func subscribeRealtime(userID: UUID) async {
        guard subscribedUserID != userID else { return }
        await teardownRealtime()
        subscribedUserID = userID

        let contentChannel = client.channel("content_items-\(userID)")
        let filter = RealtimePostgresFilter.eq("user_id", value: userID.uuidString)
        let decoder = SupabaseRealtimeCoding.decoder
        let contentData = contentData
        let content = content

        _ = contentChannel.onPostgresChange(InsertAction.self, schema: "public", table: "content_items", filter: filter) { action in
            guard let dto = try? action.decodeRecord(as: ContentItemDTO.self, decoder: decoder) else { return }
            Task { @MainActor in
                let tagIDs = (try? await contentData.fetchTagLinks(forItem: dto.id))?.map(\.tagID) ?? []
                content.applyRemoteUpsert(dto, tagIDs: tagIDs)
            }
        }
        _ = contentChannel.onPostgresChange(UpdateAction.self, schema: "public", table: "content_items", filter: filter) { action in
            guard let dto = try? action.decodeRecord(as: ContentItemDTO.self, decoder: decoder) else { return }
            Task { @MainActor in
                let tagIDs = (try? await contentData.fetchTagLinks(forItem: dto.id))?.map(\.tagID) ?? []
                content.applyRemoteUpsert(dto, tagIDs: tagIDs)
            }
        }
        _ = contentChannel.onPostgresChange(DeleteAction.self, schema: "public", table: "content_items", filter: filter) { action in
            guard let raw = action.oldRecord["id"], case .string(let idString) = raw, let id = UUID(uuidString: idString) else { return }
            Task { @MainActor in content.applyRemoteDelete(id: id) }
        }

        let collectionsChannel = client.channel("collections-\(userID)")
        let collections = collections
        _ = collectionsChannel.onPostgresChange(InsertAction.self, schema: "public", table: "collections", filter: filter) { action in
            guard let dto = try? action.decodeRecord(as: ContentCollectionDTO.self, decoder: decoder) else { return }
            Task { @MainActor in collections.applyRemoteUpsert(dto) }
        }
        _ = collectionsChannel.onPostgresChange(UpdateAction.self, schema: "public", table: "collections", filter: filter) { action in
            guard let dto = try? action.decodeRecord(as: ContentCollectionDTO.self, decoder: decoder) else { return }
            Task { @MainActor in collections.applyRemoteUpsert(dto) }
        }
        _ = collectionsChannel.onPostgresChange(DeleteAction.self, schema: "public", table: "collections", filter: filter) { action in
            guard let raw = action.oldRecord["id"], case .string(let idString) = raw, let id = UUID(uuidString: idString) else { return }
            Task { @MainActor in collections.applyRemoteDelete(id: id) }
        }

        let tagsChannel = client.channel("tags-\(userID)")
        let tags = tags
        _ = tagsChannel.onPostgresChange(InsertAction.self, schema: "public", table: "tags", filter: filter) { action in
            guard let dto = try? action.decodeRecord(as: TagDTO.self, decoder: decoder) else { return }
            Task { @MainActor in tags.applyRemoteUpsert(dto) }
        }
        _ = tagsChannel.onPostgresChange(UpdateAction.self, schema: "public", table: "tags", filter: filter) { action in
            guard let dto = try? action.decodeRecord(as: TagDTO.self, decoder: decoder) else { return }
            Task { @MainActor in tags.applyRemoteUpsert(dto) }
        }
        _ = tagsChannel.onPostgresChange(DeleteAction.self, schema: "public", table: "tags", filter: filter) { action in
            guard let raw = action.oldRecord["id"], case .string(let idString) = raw, let id = UUID(uuidString: idString) else { return }
            Task { @MainActor in tags.applyRemoteDelete(id: id) }
        }

        for channel in [contentChannel, collectionsChannel, tagsChannel] {
            try? await channel.subscribeWithError()
            realtimeChannels.append(channel)
        }
    }

    private func teardownRealtime() async {
        for channel in realtimeChannels {
            await client.removeChannel(channel)
        }
        realtimeChannels.removeAll()
        subscribedUserID = nil
    }
}
