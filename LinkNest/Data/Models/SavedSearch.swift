//
//  SavedSearch.swift
//  Recent searches shown on the Search screen.
//

import Foundation
import SwiftData

@Model
final class SavedSearch {
    @Attribute(.unique) var id: UUID
    var query: String
    var createdAt: Date

    init(id: UUID = UUID(), query: String, createdAt: Date = .now) {
        self.id = id
        self.query = query
        self.createdAt = createdAt
    }
}
