//
//  EditItemSheet.swift
//  Edit an item's title, notes, collection, tags and flags.
//

import SwiftUI

struct EditItemSheet: View {
    let itemID: UUID

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
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

    @State private var title: String
    @State private var notes: String
    @State private var selectedCollectionID: UUID?
    @State private var selectedTags: Set<String>
    @State private var isFavorite: Bool
    @State private var isWatchLater: Bool

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

    private var tagOptions: [String] {
        var options = SaveLinkViewModel.suggestedTags
        for name in item.tags.map(\.name) where !options.contains(name) {
            options.append(name)
        }
        return options
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

                LNSectionLabel(text: String(localized: "save.tags", defaultValue: "Tags"))
                    .padding(.top, 18)
                FlowLayout(spacing: 8) {
                    ForEach(tagOptions, id: \.self) { tag in
                        LNFilterChip(label: "#\(tag)", isSelected: selectedTags.contains(tag)) {
                            if selectedTags.contains(tag) { selectedTags.remove(tag) }
                            else { selectedTags.insert(tag) }
                        }
                    }
                }
                .padding(.top, 9)

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
