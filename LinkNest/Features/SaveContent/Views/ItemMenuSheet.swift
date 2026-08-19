//
//  ItemMenuSheet.swift
//  Per-item overflow actions (Open / Favorite / Watch Later / Share /
//  Archive / Delete), matching the prototype's action sheet.
//

import SwiftUI

struct ItemMenuSheet: View {
    let itemID: UUID

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let item = container.contentRepository.item(id: itemID) {
            VStack(alignment: .leading, spacing: 10) {
                Text(item.title)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(LNColor.secondaryText)
                    .lineLimit(1)
                    .padding(.top, 16)

                LNGroupCard {
                    row(String(localized: "menu.open", defaultValue: "Open")) {
                        container.contentRepository.markViewed(item)
                        router.dismissSheetThenPush(.viewer(for: item))
                    }
                    LNRowSeparator()
                    row(item.isFavorite
                        ? String(localized: "menu.unfavorite", defaultValue: "Remove from Favorites")
                        : String(localized: "menu.favorite", defaultValue: "Add to Favorites")) {
                        item.isFavorite.toggle()
                        container.contentRepository.save()
                        dismiss()
                    }
                    LNRowSeparator()
                    row(item.isWatchLater
                        ? String(localized: "menu.removeWatchLater", defaultValue: "Remove from Watch Later")
                        : String(localized: "menu.watchLater", defaultValue: "Add to Watch Later")) {
                        item.isWatchLater.toggle()
                        container.contentRepository.save()
                        dismiss()
                    }
                    LNRowSeparator()
                    ShareLink(item: URL(string: item.url) ?? URL(filePath: "/")) {
                        HStack {
                            Text(String(localized: "menu.share", defaultValue: "Share"))
                                .font(.system(size: 15))
                                .foregroundStyle(LNColor.primaryText)
                            Spacer()
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 48)
                    }
                    .buttonStyle(.plain)
                    LNRowSeparator()
                    row(String(localized: "menu.edit", defaultValue: "Edit")) {
                        router.sheet = .editItem(item.id)
                    }
                    LNRowSeparator()
                    row(String(localized: "menu.archive", defaultValue: "Archive")) {
                        container.deleteContent.archive(item)
                        dismiss()
                        appState.showToast(String(localized: "toast.archived", defaultValue: "Archived"))
                    }
                    LNRowSeparator()
                    row(String(localized: "menu.delete", defaultValue: "Delete"), tint: LNColor.destructive) {
                        container.deleteContent.delete(item)
                        dismiss()
                        appState.showToast(String(localized: "toast.deleted", defaultValue: "Moved to Recently Deleted"))
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, LNSpacing.gutter)
            .background(LNColor.background)
            .presentationDetents([.height(430)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(LNRadius.sheet)
        }
    }

    private func row(_ title: String, tint: Color = LNColor.primaryText, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(title)
                    .font(.system(size: 15))
                    .foregroundStyle(tint)
                Spacer()
            }
            .padding(.horizontal, 15)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }
}
