//
//  ModelContainerProvider.swift
//

import SwiftData

enum ModelContainerProvider {
    static func make(inMemory: Bool = false) -> ModelContainer {
        let schema = Schema([
            ContentItem.self,
            ContentCollection.self,
            Tag.self,
            UserProfile.self,
            SavedSearch.self
        ])
        let config = ModelConfiguration(schema: schema, isStoredInMemoryOnly: inMemory)
        do {
            return try ModelContainer(for: schema, configurations: [config])
        } catch {
            // A corrupt store on device should not brick the app; fall back to memory.
            let fallback = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
            return try! ModelContainer(for: schema, configurations: [fallback])
        }
    }
}
