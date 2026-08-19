//
//  CreateCollectionUseCase.swift
//

import Foundation

@MainActor
struct CreateCollectionUseCase {
    let collections: any CollectionRepository

    /// Prototype's New Collection color palette.
    static let palette: [UInt32] = [0x4A50DB, 0x7A3FD1, 0xC74B78, 0x0E8A8A, 0x2E9E5B, 0xC4880F]

    @discardableResult
    func callAsFunction(name: String, colorHex: UInt32) -> ContentCollection {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        let collection = ContentCollection(
            name: trimmed.isEmpty ? String(localized: "collections.newDefault", defaultValue: "New Collection") : trimmed,
            colorHex: colorHex
        )
        collections.insert(collection)
        return collection
    }
}
