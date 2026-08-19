//
//  SaveLinkView.swift
//  URL field + Paste · Fetch Details (skeleton → metadata card) ·
//  collection & tag pickers · notes · toggles · Save Link CTA.
//

import SwiftUI

struct SaveLinkView: View {
    var prefillURL: String?

    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @State private var vm: SaveLinkViewModel?

    var body: some View {
        Group {
            if let vm { SaveLinkContent(vm: vm) }
        }
        .task {
            guard vm == nil else { return }
            let model = SaveLinkViewModel(fetchMetadata: container.fetchMetadata,
                                          saveContent: container.saveContent,
                                          collections: container.collectionRepository,
                                          prefillURL: prefillURL)
            model.onError = { appState.showToast($0) }
            vm = model
        }
        .toolbar(.hidden, for: .navigationBar)
    }
}

private struct SaveLinkContent: View {
    @Bindable var vm: SaveLinkViewModel

    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 10) {
                    LNIconButton(systemImage: "chevron.left", tint: LNColor.primaryText,
                                 accessibilityLabel: String(localized: "a11y.back", defaultValue: "Back")) {
                        router.pop()
                    }
                    Text(String(localized: "save.title", defaultValue: "Save to LinkNest"))
                        .font(.system(size: 19, weight: .bold))
                        .foregroundStyle(LNColor.primaryText)
                }
                .padding(.horizontal, 14)

                urlField
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 16)

                LNSecondaryButton(title: String(localized: "save.fetch", defaultValue: "Fetch Details"),
                                  isEnabled: !vm.url.isEmpty) { vm.fetch() }
                    .padding(.horizontal, LNSpacing.gutter)
                    .padding(.top, 10)

                switch vm.state {
                case .idle:
                    EmptyView()
                case .loading:
                    ContentCardSkeleton()
                        .padding(.horizontal, LNSpacing.gutter)
                        .padding(.top, 16)
                case .ready(let metadata):
                    metadataCard(metadata)
                        .padding(.horizontal, LNSpacing.gutter)
                        .padding(.top, 16)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                    detailsForm
                }
            }
            .padding(.top, 6)
            .padding(.bottom, 44)
        }
        .background(LNColor.background)
        .animation(LNAnimation.sheet, value: vm.state)
    }

    private var urlField: some View {
        HStack(spacing: 9) {
            Image(systemName: "link")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(LNColor.tertiaryText)
            TextField("https://…", text: $vm.url)
                .font(LNFont.body)
                .foregroundStyle(LNColor.primaryText)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
            Button(String(localized: "save.paste", defaultValue: "Paste")) {
                if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                    vm.url = clipboard
                } else {
                    vm.pasteExample()
                }
            }
            .font(.system(size: 13, weight: .semibold))
            .foregroundStyle(LNColor.accent)
            .padding(.horizontal, 12)
            .frame(height: 32)
            .background(LNColor.accentSoft, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .buttonStyle(.plain)
        }
        .padding(.leading, 14)
        .padding(.trailing, 8)
        .frame(height: 48)
        .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .modifier(CardShadow())
    }

    private func metadataCard(_ metadata: LinkMetadata) -> some View {
        HStack(spacing: 12) {
            ThumbnailView(hue: metadata.thumbnailHue, platform: metadata.platform,
                          duration: nil, thumbnailURL: nil)
                .frame(width: 104, height: 70)
            VStack(alignment: .leading, spacing: 4) {
                Text(metadata.title)
                    .font(LNFont.cardTitle)
                    .foregroundStyle(LNColor.primaryText)
                    .lineLimit(2)
                Text("\(metadata.platform.displayName) · \(metadata.creatorName)")
                    .font(LNFont.meta)
                    .foregroundStyle(LNColor.secondaryText)
                Text(metadata.duration.map { "\(metadata.contentType.displayName) · \($0)" } ?? metadata.contentType.displayName)
                    .font(.system(size: 11))
                    .foregroundStyle(LNColor.tertiaryText)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(LNColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LNRadius.cardLarge, style: .continuous))
        .modifier(CardShadow())
    }

    private var detailsForm: some View {
        VStack(alignment: .leading, spacing: 0) {
            LNSectionLabel(text: String(localized: "save.collection", defaultValue: "Collection"))
                .padding(.top, 20)
            FlowLayout(spacing: 8) {
                ForEach(vm.allCollections) { collection in
                    LNFilterChip(label: collection.name,
                                 isSelected: vm.selectedCollectionID == collection.id) {
                        vm.selectedCollectionID = collection.id
                    }
                }
            }
            .padding(.top, 9)

            LNSectionLabel(text: String(localized: "save.tags", defaultValue: "Tags"))
                .padding(.top, 18)
            FlowLayout(spacing: 8) {
                ForEach(SaveLinkViewModel.suggestedTags, id: \.self) { tag in
                    LNFilterChip(label: "#\(tag)", isSelected: vm.selectedTags.contains(tag)) {
                        vm.toggleTag(tag)
                    }
                }
            }
            .padding(.top, 9)

            LNSectionLabel(text: String(localized: "save.notes", defaultValue: "Notes"))
                .padding(.top, 18)
            TextField(String(localized: "save.notesPlaceholder", defaultValue: "Why is this worth keeping?"),
                      text: $vm.notes, axis: .vertical)
                .font(LNFont.body)
                .foregroundStyle(LNColor.primaryText)
                .lineLimit(2...4)
                .padding(EdgeInsets(top: 12, leading: 14, bottom: 12, trailing: 14))
                .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
                .modifier(CardShadow())
                .padding(.top, 9)

            LNGroupCard {
                LNToggleRow(title: String(localized: "save.favorite", defaultValue: "Favorite"), isOn: $vm.isFavorite)
                LNRowSeparator()
                LNToggleRow(title: String(localized: "save.watchLater", defaultValue: "Watch Later"), isOn: $vm.isWatchLater)
            }
            .padding(.top, 14)

            LNPrimaryButton(title: String(localized: "save.cta", defaultValue: "Save Link")) {
                guard vm.save() != nil else { return }
                router.pop()
                router.switchTab(.saved)
                appState.showToast(String(localized: "toast.saved", defaultValue: "Saved to LinkNest"))
            }
            .modifier(AccentGlow())
            .padding(.top, 18)
        }
        .padding(.horizontal, LNSpacing.gutter)
    }
}
