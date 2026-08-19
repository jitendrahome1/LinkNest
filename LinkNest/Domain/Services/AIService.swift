//
//  AIService.swift
//  Placeholder protocol for the future AI layer. The Content Detail
//  screen renders its "Coming soon" summary card off `isAvailable`.
//  Completely replaceable: implement the protocol, register it in
//  AppContainer, and the UI lights up.
//

import Foundation

protocol AIService: Sendable {
    var isAvailable: Bool { get }
    func summarize(_ item: ContentItem) async throws -> String
    func generateTags(_ item: ContentItem) async throws -> [String]
    func categorize(_ item: ContentItem) async throws -> String
    func semanticSearch(_ query: String) async throws -> [UUID]
    func recommendContent() async throws -> [UUID]
}

struct AIUnavailableError: Error {}

struct UnavailableAIService: AIService {
    var isAvailable: Bool { false }
    func summarize(_ item: ContentItem) async throws -> String { throw AIUnavailableError() }
    func generateTags(_ item: ContentItem) async throws -> [String] { throw AIUnavailableError() }
    func categorize(_ item: ContentItem) async throws -> String { throw AIUnavailableError() }
    func semanticSearch(_ query: String) async throws -> [UUID] { throw AIUnavailableError() }
    func recommendContent() async throws -> [UUID] { throw AIUnavailableError() }
}
