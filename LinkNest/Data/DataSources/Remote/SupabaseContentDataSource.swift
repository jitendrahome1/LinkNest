//
//  SupabaseContentDataSource.swift
//  Talks to public.content_items / public.content_item_tags. Row-level
//  security scopes every query to the signed-in user, so the explicit
//  user_id filters here are belt-and-suspenders, not the real guard.
//

import Foundation
import Supabase

struct SupabaseContentDataSource: Sendable {
    private var client: SupabaseClient { SupabaseClientProvider.shared }

    func fetchAll(userID: UUID) async throws -> [ContentItemDTO] {
        try await client.from("content_items")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
    }

    func upsert(_ dto: ContentItemDTO) async throws {
        try await client.from("content_items")
            .upsert(dto, onConflict: "id")
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client.from("content_items")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }

    func fetchTagLinks(userID: UUID) async throws -> [ContentItemTagLinkDTO] {
        try await client.from("content_item_tags")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
    }

    func fetchTagLinks(forItem itemID: UUID) async throws -> [ContentItemTagLinkDTO] {
        try await client.from("content_item_tags")
            .select()
            .eq("content_item_id", value: itemID.uuidString)
            .execute()
            .value
    }

    /// Overwrites this item's tag associations with exactly `tagIDs`.
    func replaceTagLinks(itemID: UUID, tagIDs: [UUID], userID: UUID) async throws {
        try await client.from("content_item_tags")
            .delete()
            .eq("content_item_id", value: itemID.uuidString)
            .execute()
        guard !tagIDs.isEmpty else { return }
        let links = tagIDs.map { ContentItemTagLinkDTO(contentItemID: itemID, tagID: $0, userID: userID) }
        try await client.from("content_item_tags")
            .insert(links)
            .execute()
    }
}
