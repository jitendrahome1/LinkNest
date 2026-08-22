//
//  EditItemSheet.swift
//  Edit an item's title, notes, collection, tags and flags.
//

import SwiftUI

struct EditItemSheet: View {
    let itemID: UUID

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        if let item = container.contentRepository.item(id: itemID) {
            EditItemContent(item: item, dismiss: { dismiss() })
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(LNRadius.sheet)
        }
    }
}

private struct EditItemContent: View {
    let item: ContentItem
    var dismiss: () -> Void

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @State private var title: String
    @State private var notes: String
    @State private var selectedCollectionID: UUID?
    @State private var selectedTags: Set<String>
    @State private var isFavorite: Bool
    @State private var isWatchLater: Bool

    /// Inline "+ New Tag" field state, shown in place of the chip while typing.
    @State private var isAddingTag = false
    @State private var newTagName = ""

    init(item: ContentItem, dismiss: @escaping () -> Void) {
        self.item = item
        self.dismiss = dismiss
        _title = State(initialValue: item.title)
        _notes = State(initialValue: item.notes)
        _selectedCollectionID = State(initialValue: item.collection?.id)
        _selectedTags = State(initialValue: Set(item.tags.map(\.name)))
        _isFavorite = State(initialValue: item.isFavorite)
        _isWatchLater = State(initialValue: item.isWatchLater)
    }

    /// Most-used tags first, same ordering as the Save flow and Tags screen.
    private var allTags: [Tag] {
        container.tagRepository.all().sorted {
            $0.usageCount != $1.usageCount
                ? $0.usageCount > $1.usageCount
                : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private func commitNewTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard !name.isEmpty else {
            appState.showToast(String(localized: "tags.typeName", defaultValue: "Type a tag name first"))
            return
        }
        let tag = container.tagRepository.findOrCreate(named: name)
        selectedTags.insert(tag.name)
        newTagName = ""
        isAddingTag = false
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                Text(String(localized: "edit.title", defaultValue: "Edit Item"))
                    .font(LNFont.sheetTitle)
                    .foregroundStyle(LNColor.primaryText)
                    .padding(.top, 16)

                LNSectionLabel(text: String(localized: "edit.itemTitle", defaultValue: "Title"))
                    .padding(.top, 16)
                TextField(String(localized: "edit.titlePlaceholder", defaultValue: "Title"),
                          text: $title, axis: .vertical)
                    .font(LNFont.body)
                    .foregroundStyle(LNColor.primaryText)
                    .lineLimit(1...3)
                    .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
                    .modifier(CardShadow())
                    .padding(.top, 9)

                LNSectionLabel(text: String(localized: "save.notes", defaultValue: "Notes"))
                    .padding(.top, 18)
                TextField(String(localized: "save.notesPlaceholder", defaultValue: "Why is this worth keeping?"),
                          text: $notes, axis: .vertical)
                    .font(LNFont.body)
                    .foregroundStyle(LNColor.primaryText)
                    .lineLimit(2...5)
                    .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                    .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
                    .modifier(CardShadow())
                    .padding(.top, 9)

                LNSectionLabel(text: String(localized: "save.collection", defaultValue: "Collection"))
                    .padding(.top, 18)
                FlowLayout(spacing: 8) {
                    ForEach(container.collectionRepository.all()) { collection in
                        LNFilterChip(label: collection.name,
                                     isSelected: selectedCollectionID == collection.id) {
                            selectedCollectionID = selectedCollectionID == collection.id ? nil : collection.id
                        }
                    }
                }
                .padding(.top, 9)

                HStack(alignment: .firstTextBaseline) {
                    LNSectionLabel(text: String(localized: "save.tags", defaultValue: "Tags"))
                    Spacer()
                    Button {
                        router.dismissSheetThenPush(.manageTags)
                    } label: {
                        Text(String(localized: "save.manageTags", defaultValue: "Manage Tags"))
                            .font(LNFont.chip)
                            .foregroundStyle(LNColor.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.top, 18)

                FlowLayout(spacing: 8) {
                    ForEach(allTags) { tag in
                        LNFilterChip(label: "#\(tag.name)", isSelected: selectedTags.contains(tag.name)) {
                            if selectedTags.contains(tag.name) { selectedTags.remove(tag.name) }
                            else { selectedTags.insert(tag.name) }
                        }
                    }
                    if !isAddingTag {
                        Button {
                            newTagName = ""
                            isAddingTag = true
                        } label: {
                            Label(String(localized: "save.newTag", defaultValue: "New Tag"), systemImage: "plus")
                                .labelStyle(.titleAndIcon)
                                .font(LNFont.chip)
                                .foregroundStyle(LNColor.accent)
                                .padding(.horizontal, 13)
                                .frame(height: 32)
                                .background(LNColor.accentSoft, in: Capsule())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 9)

                if isAddingTag {
                    newTagField
                        .padding(.top, 9)
                }

                LNGroupCard {
                    LNToggleRow(title: String(localized: "save.favorite", defaultValue: "Favorite"), isOn: $isFavorite)
                    LNRowSeparator()
                    LNToggleRow(title: String(localized: "save.watchLater", defaultValue: "Watch Later"), isOn: $isWatchLater)
                }
                .padding(.top, 14)

                LNPrimaryButton(title: String(localized: "edit.save", defaultValue: "Save Changes")) {
                    save()
                }
                .modifier(AccentGlow())
                .padding(.top, 18)
            }
            .padding(.horizontal, LNSpacing.gutter)
            .padding(.bottom, 42)
        }
        .background(LNColor.background)
    }

    private var newTagField: some View {
        HStack(spacing: 9) {
            Text("#")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LNColor.tertiaryText)
            TextField(String(localized: "tags.newPlaceholder", defaultValue: "Create a new tag"), text: $newTagName)
                .font(LNFont.body)
                .foregroundStyle(LNColor.primaryText)
                .submitLabel(.done)
                .onSubmit(commitNewTag)
            Button {
                newTagName = ""
                isAddingTag = false
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LNColor.tertiaryText)
                    .frame(width: 32, height: 32)
                    .background(LNColor.chip, in: Circle())
            }
            .buttonStyle(.plain)
            Button(action: commitNewTag) {
                Text(String(localized: "action.add", defaultValue: "Add"))
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(LNColor.accent)
                    .padding(.horizontal, 13)
                    .frame(height: 32)
                    .background(LNColor.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            }
            .buttonStyle(.plain)
            .opacity(newTagName.trimmingCharacters(in: .whitespaces).isEmpty ? 0.45 : 1)
        }
        .padding(.horizontal, 14)
        .frame(height: 48)
        .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
        .modifier(CardShadow())
    }

    private func save() {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.title = trimmedTitle.isEmpty ? item.title : trimmedTitle
        item.notes = notes.trimmingCharacters(in: .whitespacesAndNewlines)
        item.collection = selectedCollectionID.flatMap { id in
            container.collectionRepository.all().first { $0.id == id }
        }
        item.tags = selectedTags.map { container.tagRepository.findOrCreate(named: $0) }
        item.isFavorite = isFavorite
        item.isWatchLater = isWatchLater
        item.updatedAt = .now
        container.contentRepository.save()
        dismiss()
        appState.showToast(String(localized: "toast.changesSaved", defaultValue: "Changes saved"))
    }
}
