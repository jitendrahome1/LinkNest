//
//  SeedDefaultCollectionsUseCase.swift
//  Gives every brand-new account the same starting collections from the
//  approved design, instead of an empty Collections tab. Runs once, right
//  after sign-up — never for sign-in, so an existing user's own
//  collections are never touched. Each insert goes through the normal
//  CollectionRepository, so these sync to Supabase like anything else.
//

import Foundation

@MainActor
struct SeedDefaultCollectionsUseCase {
    let collections: any CollectionRepository

    static let defaults: [(name: String, colorHex: UInt32)] = [
        ("iOS Development", 0x4A50DB),
        ("AI & Machine Learning", 0x7A3FD1),
        ("Career", 0x0E8A8A),
        ("Finance", 0x2E9E5B),
        ("Design", 0xC74B78),
        ("Learning", 0xC4880F),
        ("Travel", 0x3577D9),
        ("Inspiration", 0x8A6BE0)
    ]

    func callAsFunction() {
        guard collections.all().isEmpty else { return }
        for entry in Self.defaults {
            collections.insert(ContentCollection(name: entry.name, colorHex: entry.colorHex))
        }
    }
}
