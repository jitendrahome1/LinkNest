//
//  PDFReaderViewModel.swift
//  Downloads/caches the PDF, then owns paging, search and bookmark state.
//  Progress persists onto the ContentItem via the existing
//  ContentRepository — no separate reading-progress store.
//

import Foundation
import PDFKit
import Observation

@Observable
@MainActor
final class PDFReaderViewModel {
    enum Phase: Equatable {
        case loading
        case ready
        case failed(String)
    }

    private(set) var phase: Phase = .loading
    private(set) var document: PDFDocument?
    var currentPage: Int = 1
    private(set) var totalPages: Int = 0
    var showResumePrompt = false

    var isSearchActive = false
    var searchQuery = "" {
        didSet { scheduleSearch() }
    }
    private(set) var searchResults: [PDFSelection] = []
    private(set) var currentResultIndex = 0
    private(set) var isSearching = false

    /// Wired up by PDFReaderView once the PDFKitView coordinator exists.
    var jumpToPage: ((Int) -> Void)?
    var highlightSelection: ((PDFSelection) -> Void)?

    let item: ContentItem
    private let contentRepository: any ContentRepository
    private var searchTask: Task<Void, Never>?
    private var lastPersistedAt: Date = .distantPast

    init(item: ContentItem, contentRepository: any ContentRepository) {
        self.item = item
        self.contentRepository = contentRepository
        currentPage = max(1, item.currentPage)
        totalPages = item.totalPages
    }

    func load() async {
        phase = .loading
        guard let remoteURL = URL(string: item.url) else {
            phase = .failed(String(localized: "pdf.invalidURL", defaultValue: "This link isn't a valid document URL."))
            return
        }

        do {
            let localURL = try await Self.cachedFile(for: item.id, remote: remoteURL)
            guard let doc = PDFDocument(url: localURL) else {
                phase = .failed(String(localized: "pdf.openFailed", defaultValue: "This file couldn't be opened as a PDF."))
                return
            }
            document = doc
            totalPages = doc.pageCount
            item.totalPages = totalPages
            contentRepository.save()
            phase = .ready
            if item.hasResumableReading {
                showResumePrompt = true
            } else {
                currentPage = 1
            }
        } catch {
            phase = .failed(String(localized: "pdf.downloadFailed", defaultValue: "Couldn't download this document. Check your connection and try again."))
        }
    }

    func retry() {
        Task { await load() }
    }

    // MARK: - Resume

    func continueFromSaved() {
        showResumePrompt = false
        currentPage = max(1, item.currentPage)
        jumpToPage?(currentPage)
    }

    func startFromBeginning() {
        showResumePrompt = false
        currentPage = 1
        jumpToPage?(1)
    }

    // MARK: - Paging

    /// Called by the Coordinator whenever PDFKit's own page-change notification fires.
    func handlePageChanged(to page: Int) {
        currentPage = page
        persist(force: false)
        if totalPages > 0, page >= totalPages, !item.isCompleted {
            item.isCompleted = true
            contentRepository.save()
        }
    }

    func goToPage(_ page: Int) {
        let clamped = min(max(1, page), max(totalPages, 1))
        currentPage = clamped
        jumpToPage?(clamped)
        persist(force: true)
    }

    func scrub(toFraction fraction: Double) {
        guard totalPages > 1 else { return }
        let page = Int((fraction * Double(totalPages - 1)).rounded()) + 1
        currentPage = min(max(1, page), totalPages)
        jumpToPage?(currentPage)
    }

    func commitScrub() { persist(force: true) }

    // MARK: - Bookmarks

    var isCurrentPageBookmarked: Bool { item.bookmarkedPages.contains(currentPage) }

    func toggleBookmark() -> Bool {
        if let index = item.bookmarkedPages.firstIndex(of: currentPage) {
            item.bookmarkedPages.remove(at: index)
        } else {
            item.bookmarkedPages.append(currentPage)
            item.bookmarkedPages.sort()
        }
        contentRepository.save()
        return item.bookmarkedPages.contains(currentPage)
    }

    // MARK: - Search

    private func scheduleSearch() {
        searchTask?.cancel()
        let query = searchQuery.trimmingCharacters(in: .whitespaces)
        guard !query.isEmpty, let document else {
            searchResults = []
            currentResultIndex = 0
            isSearching = false
            return
        }
        isSearching = true
        searchTask = Task { [weak self] in
            try? await Task.sleep(for: .milliseconds(300))
            guard !Task.isCancelled else { return }
            let results = await Task.detached(priority: .userInitiated) {
                document.findString(query, withOptions: [.caseInsensitive])
            }.value
            guard !Task.isCancelled, let self, self.searchQuery.trimmingCharacters(in: .whitespaces) == query else { return }
            self.searchResults = results
            self.currentResultIndex = 0
            self.isSearching = false
            if let first = results.first { self.highlightSelection?(first) }
        }
    }

    func nextResult() {
        guard !searchResults.isEmpty else { return }
        currentResultIndex = (currentResultIndex + 1) % searchResults.count
        highlightSelection?(searchResults[currentResultIndex])
    }

    func previousResult() {
        guard !searchResults.isEmpty else { return }
        currentResultIndex = (currentResultIndex - 1 + searchResults.count) % searchResults.count
        highlightSelection?(searchResults[currentResultIndex])
    }

    func closeSearch() {
        isSearchActive = false
        searchQuery = ""
        searchResults = []
    }

    // MARK: - Persistence

    private func persist(force: Bool) {
        if !force, Date.now.timeIntervalSince(lastPersistedAt) < 1 { return }
        lastPersistedAt = .now
        item.currentPage = currentPage
        contentRepository.save()
    }

    // MARK: - Download cache

    private static func cachedFile(for id: UUID, remote: URL) async throws -> URL {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            .appending(path: "PDFCache", directoryHint: .isDirectory)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        let localURL = cacheDir.appending(path: "\(id.uuidString).pdf")

        if FileManager.default.fileExists(atPath: localURL.path) {
            return localURL
        }
        let (tempURL, response) = try await URLSession.shared.download(from: remote)
        guard (response as? HTTPURLResponse)?.statusCode == 200 else {
            throw URLError(.badServerResponse)
        }
        try? FileManager.default.removeItem(at: localURL)
        try FileManager.default.moveItem(at: tempURL, to: localURL)
        return localURL
    }
}
