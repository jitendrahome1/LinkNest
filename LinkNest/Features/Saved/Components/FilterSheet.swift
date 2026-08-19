//
//  FilterSheet.swift
//  Platform / Content Type / Status / Date chips + Reset & Apply.
//

import SwiftUI

struct FilterSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss
    @State private var dateChip: String?

    var body: some View {
        if let vm = container.savedViewModel {
            FilterSheetContent(vm: vm, dateChip: $dateChip, dismiss: { dismiss() })
                .presentationDetents([.large, .fraction(0.78)])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(LNRadius.sheet)
        }
    }
}

private struct FilterSheetContent: View {
    @Bindable var vm: SavedViewModel
    @Binding var dateChip: String?
    var dismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(String(localized: "filters.title", defaultValue: "Filters"))
                        .font(LNFont.sheetTitle)
                        .foregroundStyle(LNColor.primaryText)
                    Spacer()
                    Button(String(localized: "filters.reset", defaultValue: "Reset")) {
                        vm.filter.reset()
                        dateChip = nil
                    }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LNColor.accent)
                    .buttonStyle(.plain)
                }
                .padding(.top, 16)

                section(String(localized: "filters.platform", defaultValue: "Platform")) {
                    ForEach([ContentPlatform.youtube, .instagram, .facebook, .linkedin, .x, .website]) { platform in
                        LNFilterChip(label: platform.displayName,
                                     isSelected: vm.filter.platforms.contains(platform)) {
                            toggle(&vm.filter.platforms, platform)
                        }
                    }
                }
                section(String(localized: "filters.type", defaultValue: "Content Type")) {
                    ForEach([ContentType.video, .article, .post, .pdf]) { type in
                        LNFilterChip(label: type.displayName,
                                     isSelected: vm.filter.types.contains(type)) {
                            toggle(&vm.filter.types, type)
                        }
                    }
                }
                section(String(localized: "filters.status", defaultValue: "Status")) {
                    LNFilterChip(label: String(localized: "filters.favorite", defaultValue: "Favorite"),
                                 isSelected: vm.filter.favoritesOnly) { vm.filter.favoritesOnly.toggle() }
                    LNFilterChip(label: String(localized: "filters.watchLater", defaultValue: "Watch Later"),
                                 isSelected: vm.filter.watchLaterOnly) { vm.filter.watchLaterOnly.toggle() }
                }
                section(String(localized: "filters.saved", defaultValue: "Saved")) {
                    ForEach(["Today", "Last 7 Days", "Last 30 Days"], id: \.self) { label in
                        LNFilterChip(label: label, isSelected: dateChip == label) {
                            dateChip = dateChip == label ? nil : label
                        }
                    }
                }

                LNPrimaryButton(title: String(localized: "filters.apply", defaultValue: "Apply Filters")) { dismiss() }
                    .padding(.top, 20)
            }
            .padding(.horizontal, LNSpacing.gutter)
            .padding(.bottom, 36)
        }
        .background(LNColor.background)
    }

    private func section<Chips: View>(_ title: String, @ViewBuilder chips: () -> Chips) -> some View {
        VStack(alignment: .leading, spacing: 9) {
            Text(title.uppercased())
                .font(.system(size: 12.5, weight: .semibold))
                .kerning(0.4)
                .foregroundStyle(LNColor.secondaryText)
            FlowLayout(spacing: 8) { chips() }
        }
        .padding(.top, 16)
    }

    private func toggle<T: Hashable>(_ set: inout Set<T>, _ value: T) {
        if set.contains(value) { set.remove(value) } else { set.insert(value) }
    }
}

/// Simple wrapping layout for chips.
struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        arrange(proposal: proposal, subviews: subviews).size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (subview, position) in zip(subviews, result.positions) {
            subview.place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                          proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0, y: CGFloat = 0, rowHeight: CGFloat = 0
        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x > 0, x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
        return (CGSize(width: maxWidth, height: y + rowHeight), positions)
    }
}
