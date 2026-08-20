//
//  SupabaseCollectionDataSource.swift
//  Talks to public.collections.
//

import Foundation
import Supabase

struct SupabaseCollectionDataSource: Sendable {
    private var client: SupabaseClient { SupabaseClientProvider.shared }

    func fetchAll(userID: UUID) async throws -> [ContentCollectionDTO] {
        try await client.from("collections")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
    }

    func upsert(_ dto: ContentCollectionDTO) async throws {
        try await client.from("collections")
            .upsert(dto, onConflict: "id")
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client.from("collections")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
