//
//  TagManagementView.swift
//  Global tag list, reached from Profile → Manage Tags: create a tag ahead
//  of time, see how many items each one is used on, and delete a tag
//  everywhere it's applied. Distinct from EditItemSheet's tag picker, which
//  only toggles tags that already exist onto a single item.
//

import SwiftUI
import SwiftData

struct TagManagementView: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    @Query(sort: \Tag.name) private var tags: [Tag]
    @Query(filter: #Predicate<ContentItem> { !$0.isArchived }) private var items: [ContentItem]

    @State private var newTagName = ""
    @State private var sortByUsage = true
    /// Tap-again-to-confirm delete, matching the collection/collection-menu
    /// pattern elsewhere — auto-resets after a few seconds so a stray second
    /// tap on the wrong row later can't delete something unintended.
    @State private var pendingDeleteID: UUID?
    @State private var confirmResetTask: Task<Void, Never>?

    private var sortedTags: [Tag] {
        sortByUsage
            ? tags.sorted {
                $0.usageCount != $1.usageCount
                    ? $0.usageCount > $1.usageCount
                    : $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            : tags.sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    private var taggedItemCount: Int {
        items.filter { !$0.tags.isEmpty }.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                header
                addTagField
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 16)

                HStack(alignment: .firstTextBaseline) {
                    LNSectionLabel(text: String(localized: "tags.allTags", defaultValue: "All Tags"))
                    Spacer()
                    Button(action: { sortByUsage.toggle() }) {
                        Text(sortByUsage
                             ? String(localized: "tags.sortAZ", defaultValue: "A – Z")
                             : String(localized: "tags.sortMostUsed", defaultValue: "Most used"))
                            .font(LNFont.chip)
                            .foregroundStyle(LNColor.accent)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal, LNSpacing.gutter)
                .padding(.top, 22)
                .padding(.bottom, 9)

                if sortedTags.isEmpty {
                    LNEmptyState(systemImage: "tag",
                                 title: String(localized: "tags.emptyTitle", defaultValue: "No tags yet"),
                                 message: String(localized: "tags.emptyBody", defaultValue: "Create a tag above, or add one while saving a link."))
                } else {
                    VStack(spacing: 8) {
                        ForEach(sortedTags) { tag in
                            tagRow(tag)
                        }
                    }
                    .padding(.horizontal, LNSpacing.gutter)
                }
            }
            .padding(.bottom, 40)
        }
        .background(LNColor.background)
        .toolbar(.hidden, for: .navigationBar)
        .onDisappear { confirmResetTask?.cancel() }
    }

    private var header: some View {
        HStack(spacing: 12) {
            LNIconButton(systemImage: "chevron.left", tint: LNColor.primaryText,
                         accessibilityLabel: String(localized: "a11y.back", defaultValue: "Back")) {
                router.pop()
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(String(localized: "tags.title", defaultValue: "Tags"))
                    .font(LNFont.sheetTitle)
                    .foregroundStyle(LNColor.primaryText)
                Text(String(localized: "tags.subtitle", defaultValue: "\(tags.count) tags · used across \(taggedItemCount) items"))
                    .font(.system(size: 11))
                    .foregroundStyle(LNColor.tertiaryText)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.top, 6)
    }

    private var addTagField: some View {
        HStack(spacing: 9) {
            Text("#")
                .font(.system(size: 16, weight: .bold))
                .foregroundStyle(LNColor.tertiaryText)
            TextField(String(localized: "tags.newPlaceholder", defaultValue: "Create a new tag"), text: $newTagName)
                .font(LNFont.body)
                .foregroundStyle(LNColor.primaryText)
                .submitLabel(.done)
                .onSubmit(addTag)
            Button(action: addTag) {
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

    private func addTag() {
        let name = newTagName.trimmingCharacters(in: .whitespaces).replacingOccurrences(of: "#", with: "")
        guard !name.isEmpty else {
            appState.showToast(String(localized: "tags.typeName", defaultValue: "Type a tag name first"))
            return
        }
        guard !tags.contains(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) else {
            newTagName = ""
            appState.showToast(String(localized: "tags.alreadyExists", defaultValue: "“\(name)” already exists"))
            return
        }
        _ = container.tagRepository.findOrCreate(named: name)
        newTagName = ""
        appState.showToast(String(localized: "tags.created", defaultValue: "Tag #\(name) created"))
    }

    @ViewBuilder
    private func tagRow(_ tag: Tag) -> some View {
        let isPending = pendingDeleteID == tag.id
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 11, style: .continuous)
                .fill(LNColor.accentSoft)
                .frame(width: 34, height: 34)
                .overlay {
                    Text("#")
                        .font(.system(size: 14, weight: .heavy))
                        .foregroundStyle(LNColor.accent)
                }

            Button {
                container.savedFilterRequest = .tag(tag.name)
                router.switchTab(.saved)
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    Text(tag.name)
                        .font(.system(size: 14.5, weight: .semibold))
                        .foregroundStyle(LNColor.primaryText)
                        .lineLimit(1)
                    Text(tag.usageCount == 1
                         ? String(localized: "tags.oneItem", defaultValue: "1 item")
                         : String(localized: "tags.nItems", defaultValue: "\(tag.usageCount) items"))
                        .font(.system(size: 12))
                        .foregroundStyle(LNColor.secondaryText)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)

            Button(action: { requestDelete(tag) }) {
                if isPending {
                    Text(String(localized: "action.sure", defaultValue: "Sure?"))
                        .font(.system(size: 11.5, weight: .bold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 11)
                        .frame(height: 32)
                        .background(LNColor.destructive, in: Capsule())
                } else {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(LNColor.tertiaryText)
                        .frame(width: 32, height: 32)
                        .background(LNColor.chip, in: Circle())
                }
            }
            .buttonStyle(.plain)
            .animation(LNAnimation.selection, value: isPending)
        }
        .padding(.horizontal, 13)
        .frame(height: 58)
        .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
        .modifier(CardShadow())
    }

    /// First tap arms a 2.6s confirm window (long enough to read, short
    /// enough that a delayed second tap on some other row later can't land
    /// as an accidental delete); a second tap inside that window deletes the
    /// tag from every item that has it, matching CollectionMenuSheet's
    /// tap-again-to-delete pattern.
    private func requestDelete(_ tag: Tag) {
        guard pendingDeleteID != tag.id else {
            confirmResetTask?.cancel()
            let name = tag.name
            container.tagRepository.delete(tag)
            pendingDeleteID = nil
            appState.showToast(String(localized: "toast.tagDeleted", defaultValue: "Tag #\(name) deleted"))
            return
        }
        pendingDeleteID = tag.id
        confirmResetTask?.cancel()
        confirmResetTask = Task {
            try? await Task.sleep(for: .seconds(2.6))
            guard !Task.isCancelled else { return }
            pendingDeleteID = nil
        }
    }
}
