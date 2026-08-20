//
//  TagRepository.swift
//

import Auth
import Foundation
import Supabase
import SwiftData

@MainActor
protocol TagRepository: AnyObject {
    func all() -> [Tag]
    func findOrCreate(named name: String) -> Tag
    func delete(_ tag: Tag)

    func syncPull() async
    func applyRemoteUpsert(_ dto: TagDTO)
    func applyRemoteDelete(id: UUID)
    func clearLocal()
}

@MainActor
final class SwiftDataTagRepository: TagRepository {
    private let context: ModelContext
    private let remote: SupabaseTagDataSource

    init(context: ModelContext, remote: SupabaseTagDataSource) {
        self.context = context
        self.remote = remote
    }

    func all() -> [Tag] {
        let descriptor = FetchDescriptor<Tag>(sortBy: [SortDescriptor(\.name)])
        return (try? context.fetch(descriptor)) ?? []
    }

    func findOrCreate(named name: String) -> Tag {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        if let existing = all().first(where: { $0.name.caseInsensitiveCompare(trimmed) == .orderedSame }) {
            return existing
        }
        let tag = Tag(name: trimmed)
        context.insert(tag)
        try? context.save()
        pushUpsert(tag)
        return tag
    }

    func delete(_ tag: Tag) {
        let id = tag.id
        context.delete(tag)
        try? context.save()
        pushDelete(id)
    }

    // MARK: - Remote mirror

    private func pushUpsert(_ tag: Tag) {
        guard let userID = SupabaseClientProvider.shared.auth.currentSession?.user.id else { return }
        let dto = TagDTO(tag: tag, userID: userID)
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

    func applyRemoteUpsert(_ dto: TagDTO) {
        if let existing = all().first(where: { $0.id == dto.id }) {
            existing.name = dto.name
        } else {
            context.insert(dto.makeTag())
        }
        try? context.save()
    }

    func applyRemoteDelete(id: UUID) {
        guard let existing = all().first(where: { $0.id == id }) else { return }
        context.delete(existing)
        try? context.save()
    }

    func clearLocal() {
        for tag in all() { context.delete(tag) }
        try? context.save()
    }
}
