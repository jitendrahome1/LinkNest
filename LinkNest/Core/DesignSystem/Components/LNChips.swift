//
//  LNChips.swift
//  Selectable filter chips, tag chips and the 4-option segmented control.
//

import SwiftUI

/// Selectable pill (filter sheet, collection picker, tag picker).
struct LNFilterChip: View {
    var label: String
    var isSelected: Bool
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(label)
                .font(LNFont.chip)
                .foregroundStyle(isSelected ? .white : LNColor.primaryText)
                .padding(.horizontal, 13)
                .frame(height: 32)
                .background(isSelected ? LNColor.accent : LNColor.chip,
                            in: Capsule())
        }
        .buttonStyle(.plain)
        .animation(LNAnimation.selection, value: isSelected)
        .accessibilityLabel(label)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// Static accent-tinted tag pill ("#SwiftUI").
struct LNTagChip: View {
    var name: String

    var body: some View {
        Text("#\(name)")
            .font(.system(size: 12, weight: .medium))
            .foregroundStyle(LNColor.accent)
            .padding(.horizontal, 9)
            .frame(height: 24)
            .background(LNColor.accentSoft, in: Capsule())
    }
}

/// All / Videos / Articles / Posts segmented control.
struct LNSegmentedControl: View {
    @Binding var selection: ContentSegment

    var body: some View {
        HStack(spacing: 0) {
            ForEach(ContentSegment.allCases) { segment in
                Button {
                    withAnimation(LNAnimation.selection) { selection = segment }
                } label: {
                    Text(segment.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(selection == segment ? LNColor.primaryText : LNColor.secondaryText)
                        .frame(maxWidth: .infinity)
                        .frame(height: 30)
                        .background {
                            if selection == segment {
                                RoundedRectangle(cornerRadius: 9, style: .continuous)
                                    .fill(LNColor.cardBackground)
                                    .shadow(color: Color(hex: 0x0A0A1E, alpha: 0.14), radius: 4, y: 1)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == segment ? .isSelected : [])
            }
        }
        .padding(3)
        .background(LNColor.chip, in: RoundedRectangle(cornerRadius: 11, style: .continuous))
    }
}
