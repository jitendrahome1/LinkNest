//
//  CollectionMenuSheet.swift
//  Per-collection overflow actions (Open / Rename & Recolor / Delete),
//  matching the prototype's collection action sheet.
//

import SwiftUI

struct CollectionMenuSheet: View {
    let collectionID: UUID

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    @State private var isConfirmingDelete = false

    var body: some View {
        if let collection = container.collectionRepository.collection(id: collectionID) {
            let tint = Color(hex: collection.colorHex)

            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 11) {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(tint.opacity(0.13))
                        .frame(width: 38, height: 38)
                        .overlay {
                            Text(collection.initial)
                                .font(.system(size: 15, weight: .heavy))
                                .foregroundStyle(tint)
                        }
                    VStack(alignment: .leading, spacing: 1) {
                        Text(collection.name)
                            .font(.system(size: 15.5, weight: .bold))
                            .foregroundStyle(LNColor.primaryText)
                            .lineLimit(1)
                        Text("\(collection.activeItemCount) items")
                            .font(.system(size: 12))
                            .foregroundStyle(LNColor.secondaryText)
                    }
                }
                .padding(.top, 16)
                .padding(.bottom, 12)

                LNGroupCard {
                    row(String(localized: "collectionMenu.open", defaultValue: "Open Collection")) {
                        router.dismissSheetThenPush(.collectionDetail(collection.id))
                    }
                    LNRowSeparator()
                    row(String(localized: "collectionMenu.rename", defaultValue: "Rename & Recolor")) {
                        router.sheet = .editCollection(collection.id)
                    }
                    LNRowSeparator()
                    deleteRow(collection)
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, LNSpacing.gutter)
            .background(LNColor.background)
            .presentationDetents([.height(260)])
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

    private func deleteRow(_ collection: ContentCollection) -> some View {
        Button {
            guard isConfirmingDelete else {
                isConfirmingDelete = true
                return
            }
            let id = collection.id
            container.collectionRepository.delete(collection)
            if router.collectionsPath.last == .collectionDetail(id) {
                router.pop()
            }
            dismiss()
            appState.showToast(String(localized: "toast.collectionDeleted", defaultValue: "Collection deleted · items kept"))
        } label: {
            HStack {
                Text(isConfirmingDelete
                     ? String(localized: "collectionMenu.deleteConfirm", defaultValue: "Tap again to delete")
                     : String(localized: "collectionMenu.delete", defaultValue: "Delete Collection"))
                    .font(.system(size: 15))
                    .foregroundStyle(LNColor.destructive)
                Spacer()
                if !isConfirmingDelete {
                    Text(String(localized: "collectionMenu.deleteHint", defaultValue: "Items stay in Saved"))
                        .font(.system(size: 12))
                        .foregroundStyle(LNColor.tertiaryText)
                }
            }
            .padding(.horizontal, 15)
            .frame(height: 48)
        }
        .buttonStyle(.plain)
    }
}
