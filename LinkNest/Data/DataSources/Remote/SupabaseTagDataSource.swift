//
//  SupabaseTagDataSource.swift
//  Talks to public.tags.
//

import Foundation
import Supabase

struct SupabaseTagDataSource: Sendable {
    private var client: SupabaseClient { SupabaseClientProvider.shared }

    func fetchAll(userID: UUID) async throws -> [TagDTO] {
        try await client.from("tags")
            .select()
            .eq("user_id", value: userID.uuidString)
            .execute()
            .value
    }

    func upsert(_ dto: TagDTO) async throws {
        try await client.from("tags")
            .upsert(dto, onConflict: "id")
            .execute()
    }

    func delete(id: UUID) async throws {
        try await client.from("tags")
            .delete()
            .eq("id", value: id.uuidString)
            .execute()
    }
}
