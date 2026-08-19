//
//  UserProfile.swift
//

import Foundation
import SwiftData

@Model
final class UserProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var email: String
    var createdAt: Date

    var initials: String {
        let parts = name.split(separator: " ").prefix(2)
        return parts.map { String($0.prefix(1)).uppercased() }.joined()
    }

    init(id: UUID = UUID(), name: String, email: String, createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.email = email
        self.createdAt = createdAt
    }
}
