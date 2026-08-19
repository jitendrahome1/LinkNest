//
//  ContentDetailView.swift
//  Hero thumbnail · title/creator/URL · Open Original · My Notes ·
//  AI Summary placeholder · Details card · Share/Edit/Archive/Delete.
//

import SwiftUI
import SwiftData

struct ContentDetailView: View {
    let itemID: UUID

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        Group {
            if let item = container.contentRepository.item(id: itemID) {
                DetailContent(item: item)
            } else {
                LNEmptyState(systemImage: "questionmark.folder",
                             title: String(localized: "detail.missing", defaultValue: "Content not found"),
                             message: String(localized: "detail.missingBody", defaultValue: "This item may have been deleted."))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(LNColor.background)
            }
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct DetailContent: View {
    @Bindable var item: ContentItem

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.openURL) private var openURL

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                topBar
                ThumbnailView(hue: item.thumbnailHue, platform: item.platform,
                              duration: item.duration, thumbnailURL: item.thumbnailURL,
                              cornerRadius: LNRadius.hero, badgeScale: 1.35, contentType: item.contentType)
                    .frame(height: 200)
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 12)

                VStack(alignment: .leading, spacing: 0) {
                    Text(item.title)
                        .font(.system(size: 20, weight: .bold))
                        .kerning(-0.3)
                        .lineSpacing(3)
                        .foregroundStyle(LNColor.primaryText)
                    Text("\(item.platform.displayName) · \(item.creatorName)")
                        .font(.system(size: 13.5))
                        .foregroundStyle(LNColor.secondaryText)
                        .padding(.top, 7)
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.system(size: 12, weight: .semibold))
                        Text(item.url)
                            .font(.system(size: 12.5))
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .foregroundStyle(LNColor.accent)
                    .padding(.top, 8)

                    LNPrimaryButton(title: String(localized: "detail.openOriginal", defaultValue: "Open Original"),
                                    systemImage: "arrow.up.right") {
                        if let url = URL(string: item.url) { openURL(url) }
                    }
                    .padding(.top, 14)

                    LNSectionLabel(text: String(localized: "detail.notes", defaultValue: "My Notes"))
                        .padding(.top, 22)
                    notesCard.padding(.top, 8)

                    LNSectionLabel(text: String(localized: "detail.aiSummary", defaultValue: "AI Summary"))
                        .padding(.top, 20)
                    aiCard.padding(.top, 8)

                    LNSectionLabel(text: String(localized: "detail.details", defaultValue: "Details"))
                        .padding(.top, 20)
                    detailsCard.padding(.top, 8)

                    actionRow.padding(.top, 18)
                }
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 16)
            }
            .padding(.bottom, 44)
        }
        .background(LNColor.background)
    }

    private var topBar: some View {
        HStack {
            LNIconButton(systemImage: "chevron.left", tint: LNColor.primaryText,
                         accessibilityLabel: String(localized: "a11y.back", defaultValue: "Back")) {
                router.pop()
            }
            Spacer()
            HStack(spacing: 8) {
                LNIconButton(systemImage: item.isFavorite ? "heart.fill" : "heart",
                             tint: item.isFavorite ? LNColor.accent : LNColor.primaryText,
                             accessibilityLabel: String(localized: "a11y.favorite", defaultValue: "Favorite")) {
                    item.isFavorite.toggle()
                    container.contentRepository.save()
                }
                LNIconButton(systemImage: "ellipsis", tint: LNColor.primaryText,
                             accessibilityLabel: String(localized: "a11y.moreActions", defaultValue: "More actions")) {
                    router.sheet = .itemMenu(item.id)
                }
            }
        }
        .padding(.horizontal, 14)
    }

    private var notesCard: some View {
        Button {
            router.sheet = .editItem(item.id)
        } label: {
            Text(item.notes.isEmpty
                 ? String(localized: "detail.addNote", defaultValue: "Add a note…")
                 : item.notes)
                .font(.system(size: 14))
                .lineSpacing(4)
                .foregroundStyle(item.notes.isEmpty ? LNColor.tertiaryText : LNColor.primaryText)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
                .background(LNColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CardShadow())
        .accessibilityLabel(String(localized: "a11y.editNotes", defaultValue: "Edit notes"))
    }

    private var aiCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LNColor.accent)
                Text(String(localized: "detail.summary", defaultValue: "Summary"))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LNColor.primaryText)
                Text(String(localized: "detail.comingSoon", defaultValue: "Coming soon"))
                    .font(.system(size: 10.5, weight: .semibold))
                    .foregroundStyle(LNColor.accent)
                    .padding(.horizontal, 8)
                    .frame(height: 20)
                    .background(LNColor.accentSoft, in: Capsule())
            }
            Text(String(localized: "detail.aiBody", defaultValue: "When LinkNest AI launches, a short summary and key points for this content will appear here automatically."))
                .font(.system(size: 13))
                .lineSpacing(4)
                .foregroundStyle(LNColor.secondaryText)
            VStack(alignment: .leading, spacing: 7) {
                SkeletonBar(height: 8).frame(maxWidth: .infinity)
                SkeletonBar(height: 8).frame(maxWidth: 250)
                SkeletonBar(height: 8).frame(maxWidth: 190)
            }
            .padding(.top, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(EdgeInsets(top: 13, leading: 14, bottom: 14, trailing: 14))
        .background(LNColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
        .modifier(CardShadow())
    }

    private var detailsCard: some View {
        LNGroupCard {
            HStack {
                Text(String(localized: "detail.collection", defaultValue: "Collection"))
                    .font(LNFont.callout).foregroundStyle(LNColor.secondaryText)
                Spacer()
                if let collection = item.collection {
                    Text(collection.name)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Color(hex: collection.colorHex))
                        .padding(.horizontal, 10)
                        .frame(height: 24)
                        .background(Color(hex: collection.colorHex).opacity(0.13), in: Capsule())
                } else {
                    Text(String(localized: "detail.none", defaultValue: "None"))
                        .font(LNFont.callout).foregroundStyle(LNColor.tertiaryText)
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            LNRowSeparator()
            HStack(alignment: .center) {
                Text(String(localized: "detail.tags", defaultValue: "Tags"))
                    .font(LNFont.callout).foregroundStyle(LNColor.secondaryText)
                Spacer()
                HStack(spacing: 6) {
                    ForEach(item.tags) { tag in LNTagChip(name: tag.name) }
                }
            }
            .padding(.horizontal, 14)
            .frame(minHeight: 46)
            LNRowSeparator()
            LNDetailRow(label: String(localized: "detail.saved", defaultValue: "Saved"), value: item.savedAgo)
            LNRowSeparator()
            LNDetailRow(label: String(localized: "detail.lastViewed", defaultValue: "Last viewed"), value: item.lastViewedLabel)
        }
    }

    private var actionRow: some View {
        HStack(spacing: 9) {
            ShareLink(item: URL(string: item.url) ?? URL(filePath: "/")) {
                VStack(spacing: 5) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.system(size: 16, weight: .medium))
                    Text(String(localized: "action.share", defaultValue: "Share"))
                        .font(.system(size: 10.5, weight: .medium))
                }
                .foregroundStyle(LNColor.primaryText)
                .frame(maxWidth: .infinity)
                .frame(height: 62)
                .background(LNColor.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
            }
            .buttonStyle(.plain)
            .modifier(CardShadow())
            .accessibilityLabel(String(localized: "action.share", defaultValue: "Share"))
            DetailAction(systemImage: "pencil", label: String(localized: "action.edit", defaultValue: "Edit")) {
                router.sheet = .editItem(item.id)
            }
            DetailAction(systemImage: "archivebox", label: String(localized: "action.archive", defaultValue: "Archive")) {
                container.deleteContent.archive(item)
                router.pop()
                appState.showToast(String(localized: "toast.archived", defaultValue: "Archived"))
            }
            DetailAction(systemImage: "trash", label: String(localized: "action.delete", defaultValue: "Delete"),
                         tint: LNColor.destructive) {
                container.deleteContent.delete(item)
                router.pop()
                appState.showToast(String(localized: "toast.deleted", defaultValue: "Moved to Recently Deleted"))
            }
        }
    }
}

private struct DetailAction: View {
    var systemImage: String
    var label: String
    var tint: Color = LNColor.primaryText
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 16, weight: .medium))
                Text(label)
                    .font(.system(size: 10.5, weight: .medium))
            }
            .foregroundStyle(tint)
            .frame(maxWidth: .infinity)
            .frame(height: 62)
            .background(LNColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CardShadow())
        .accessibilityLabel(label)
    }
}
