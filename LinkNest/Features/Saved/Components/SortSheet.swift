//
//  SortSheet.swift
//

import SwiftUI

struct SortSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "sort.title", defaultValue: "Sort By"))
                .font(LNFont.sheetTitle)
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 16)

            LNGroupCard {
                ForEach(Array(SortOption.allCases.enumerated()), id: \.element) { index, option in
                    Button {
                        container.savedViewModel?.filter.sort = option
                        dismiss()
                    } label: {
                        HStack {
                            Text(option.label)
                                .font(.system(size: 15))
                                .foregroundStyle(LNColor.primaryText)
                            Spacer()
                            if container.savedViewModel?.filter.sort == option {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LNColor.accent)
                            }
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(container.savedViewModel?.filter.sort == option ? .isSelected : [])
                    if index < SortOption.allCases.count - 1 { LNRowSeparator() }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LNSpacing.gutter)
        .background(LNColor.background)
        .presentationDetents([.height(400)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(LNRadius.sheet)
    }
}
