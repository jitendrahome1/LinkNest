//
//  LinkNestPlaybackSpeedSheet.swift
//  Same LNGroupCard row list as SortSheet/ItemMenuSheet, listing the
//  standard playback rates with a checkmark on the active one.
//

import SwiftUI

struct LinkNestPlaybackSpeedSheet: View {
    static let speeds: [Double] = [0.5, 0.75, 1, 1.25, 1.5, 2]

    @Binding var selected: Double
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(String(localized: "player.speed", defaultValue: "Playback Speed"))
                .font(LNFont.sheetTitle)
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 16)

            LNGroupCard {
                ForEach(Array(Self.speeds.enumerated()), id: \.element) { index, speed in
                    Button {
                        selected = speed
                        dismiss()
                    } label: {
                        HStack {
                            Text(Self.label(for: speed))
                                .font(.system(size: 15))
                                .foregroundStyle(LNColor.primaryText)
                            Spacer()
                            if selected == speed {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(LNColor.accent)
                            }
                        }
                        .padding(.horizontal, 15)
                        .frame(height: 48)
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(selected == speed ? .isSelected : [])
                    if index < Self.speeds.count - 1 { LNRowSeparator() }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LNSpacing.gutter)
        .background(LNColor.background)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(LNRadius.sheet)
    }

    static func label(for speed: Double) -> String {
        speed == 1 ? String(localized: "player.speedNormal", defaultValue: "Normal")
                   : "\(speed.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(speed)) : String(speed))×"
    }
}
