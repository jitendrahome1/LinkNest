//
//  PDFReaderView.swift
//  PDFKit reader matching the Content Viewer prototype: title/page-count
//  toolbar, full-bleed document, page scrub + bookmark/share/open-
//  externally row. Follows the app's normal light/dark theme.
//

import SwiftUI
import PDFKit

struct PDFReaderView: View {
    let itemID: UUID

    @Environment(AppContainer.self) private var container
    @State private var vm: PDFReaderViewModel?
    @State private var itemMissing = false

    var body: some View {
        ZStack {
            LNColor.background.ignoresSafeArea()
            if let vm {
                PDFReaderContent(vm: vm)
            } else if itemMissing {
                LNEmptyState(systemImage: "questionmark.folder",
                             title: String(localized: "detail.missing", defaultValue: "Content not found"),
                             message: String(localized: "detail.missingBody", defaultValue: "This item may have been deleted."))
            } else {
                LinkNestViewerLoadingView(message: String(localized: "pdf.opening", defaultValue: "Opening document…"))
            }
        }
        .task {
            guard vm == nil else { return }
            guard let item = container.contentRepository.item(id: itemID) else {
                itemMissing = true
                return
            }
            let model = PDFReaderViewModel(item: item, contentRepository: container.contentRepository)
            vm = model
            await model.load()
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct PDFReaderContent: View {
    @Bindable var vm: PDFReaderViewModel

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL
    @FocusState private var searchFocused: Bool
    @State private var showBookmarksSheet = false

    private var item: ContentItem { vm.item }

    private var subtitle: String {
        let pages = max(vm.totalPages, item.totalPages)
        return pages > 0
            ? String(localized: "pdf.subtitle", defaultValue: "PDF · \(pages) pages")
            : "PDF"
    }

    var body: some View {
        VStack(spacing: 0) {
            if vm.isSearchActive {
                LinkNestPDFSearch(query: $vm.searchQuery,
                                  resultCount: vm.searchResults.count,
                                  currentIndex: vm.currentResultIndex,
                                  isSearching: vm.isSearching,
                                  onPrevious: vm.previousResult,
                                  onNext: vm.nextResult,
                                  onClose: { vm.closeSearch(); searchFocused = false },
                                  isFocused: $searchFocused)
                    .padding(.top, 6)
                    .onAppear { searchFocused = true }
            } else {
                LinkNestPDFToolbar(title: item.title, subtitle: subtitle,
                                   onBack: { router.pop() },
                                   onSearch: { vm.isSearchActive = true },
                                   onMore: { router.sheet = .itemMenu(item.id) })
                    .padding(.top, 6)
            }

            ZStack {
                switch vm.phase {
                case .loading:
                    LinkNestViewerLoadingView(message: String(localized: "pdf.opening", defaultValue: "Opening document…"))
                case .failed(let message):
                    LinkNestViewerErrorView(title: String(localized: "pdf.errorTitle", defaultValue: "Couldn't open document"),
                                            message: message,
                                            retryTitle: String(localized: "action.retry", defaultValue: "Retry"),
                                            onRetry: vm.retry,
                                            secondaryTitle: String(localized: "pdf.openExternally", defaultValue: "Open Externally"),
                                            onSecondary: openOriginal)
                case .ready:
                    if let document = vm.document {
                        PDFKitView(document: document,
                                  currentPage: $vm.currentPage,
                                  onPageChanged: vm.handlePageChanged,
                                  onJumpToPageReady: { vm.jumpToPage = $0 },
                                  onHighlightReady: { vm.highlightSelection = $0 })
                    }
                    if vm.showResumePrompt {
                        Color.black.opacity(0.25).ignoresSafeArea()
                        resumePrompt
                    }
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            if case .ready = vm.phase, !vm.showResumePrompt {
                bottomControls
            }
        }
        .background(LNColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .sheet(isPresented: $showBookmarksSheet) {
            bookmarksSheet
        }
    }

    private var resumePrompt: some View {
        VStack(spacing: 14) {
            Image(systemName: "arrow.counterclockwise.circle.fill")
                .font(.system(size: 34))
                .foregroundStyle(LNColor.accent)
            Text(String(localized: "pdf.continueFrom", defaultValue: "Continue from page \(item.currentPage)?"))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(LNColor.primaryText)
            HStack(spacing: 10) {
                Button(String(localized: "pdf.startBeginning", defaultValue: "Start from Beginning"), action: vm.startFromBeginning)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LNColor.primaryText)
                    .padding(.horizontal, 16)
                    .frame(height: 40)
                    .background(LNColor.chip, in: Capsule())
                Button(String(localized: "player.continue", defaultValue: "Continue"), action: vm.continueFromSaved)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 18)
                    .frame(height: 40)
                    .background(LNColor.accent, in: Capsule())
            }
        }
        .buttonStyle(.plain)
        .padding(20)
        .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: LNRadius.cardLarge, style: .continuous))
        .modifier(CardShadow())
        .padding(.horizontal, 40)
    }

    private var bottomControls: some View {
        VStack(spacing: 10) {
            LinkNestPDFPageIndicator(currentPage: vm.currentPage,
                                     totalPages: max(vm.totalPages, item.totalPages),
                                     onScrub: vm.scrub,
                                     onScrubEnd: vm.commitScrub)

            HStack(spacing: 22) {
                Spacer()
                LinkNestPDFBookmarkButton(isBookmarked: vm.isCurrentPageBookmarked) {
                    appState.showToast(vm.toggleBookmark()
                        ? String(localized: "pdf.bookmarked", defaultValue: "Bookmarked page \(vm.currentPage)")
                        : String(localized: "pdf.bookmarkRemoved", defaultValue: "Bookmark removed"))
                }

                Button {
                    showBookmarksSheet = true
                } label: {
                    ZStack(alignment: .topTrailing) {
                        Circle().fill(LNColor.chip).frame(width: 38, height: 38)
                            .overlay {
                                Image(systemName: "list.bullet")
                                    .font(.system(size: 15))
                                    .foregroundStyle(LNColor.secondaryText)
                            }
                        if !item.bookmarkedPages.isEmpty {
                            Circle().fill(LNColor.accent).frame(width: 7, height: 7).offset(x: -3, y: 3)
                        }
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "pdf.viewBookmarks", defaultValue: "View bookmarks"))

                ShareLink(item: URL(string: item.url) ?? URL(filePath: "/")) {
                    Circle().fill(LNColor.chip).frame(width: 38, height: 38)
                        .overlay {
                            Image(systemName: "square.and.arrow.up")
                                .font(.system(size: 15))
                                .foregroundStyle(LNColor.secondaryText)
                        }
                }
                .buttonStyle(.plain)

                Button(action: openOriginal) {
                    Circle().fill(LNColor.chip).frame(width: 38, height: 38)
                        .overlay {
                            Image(systemName: "arrow.up.forward.square")
                                .font(.system(size: 15))
                                .foregroundStyle(LNColor.secondaryText)
                        }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(String(localized: "pdf.openExternally", defaultValue: "Open Externally"))
                Spacer()
            }
        }
        .padding(.horizontal, LNSpacing.gutter)
        .padding(.top, 4)
        .padding(.bottom, 10)
    }

    private var bookmarksSheet: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "pdf.bookmarksTitle", defaultValue: "Bookmarks"))
                .font(LNFont.sheetTitle)
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 16)

            if item.bookmarkedPages.isEmpty {
                LNEmptyState(systemImage: "bookmark",
                             title: String(localized: "pdf.noBookmarksTitle", defaultValue: "No bookmarks yet"),
                             message: String(localized: "pdf.noBookmarksBody", defaultValue: "Bookmark a page and it'll show up here."))
            } else {
                LNGroupCard {
                    ForEach(Array(item.bookmarkedPages.sorted().enumerated()), id: \.element) { index, page in
                        Button {
                            vm.goToPage(page)
                            showBookmarksSheet = false
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                    .font(.system(size: 13))
                                    .foregroundStyle(LNColor.accent)
                                Text(String(localized: "pdf.pageLabel", defaultValue: "Page \(page)"))
                                    .font(.system(size: 15))
                                    .foregroundStyle(LNColor.primaryText)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(LNColor.tertiaryText)
                            }
                            .padding(.horizontal, 15)
                            .frame(height: 48)
                        }
                        .buttonStyle(.plain)
                        if index < item.bookmarkedPages.count - 1 { LNRowSeparator() }
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LNSpacing.gutter)
        .background(LNColor.background)
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(LNRadius.sheet)
    }

    private func openOriginal() {
        if let url = URL(string: item.url) { openURL(url) }
    }
}
