//
//  LNCollectionCard.swift
//

import SwiftUI

struct LNCollectionCard: View {
    let collection: ContentCollection
    /// Larger variant on the Collections screen; smaller on Home.
    var showsThumbnails = false
    var onOpen: () -> Void

    private var tint: Color { Color(hex: collection.colorHex) }

    var body: some View {
        Button(action: onOpen) {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .top) {
                    RoundedRectangle(cornerRadius: showsThumbnails ? 14 : LNRadius.iconTile, style: .continuous)
                        .fill(tint.opacity(0.13))
                        .frame(width: showsThumbnails ? 44 : 40, height: showsThumbnails ? 44 : 40)
                        .overlay {
                            Text(collection.initial)
                                .font(.system(size: showsThumbnails ? 17 : 16, weight: .heavy))
                                .foregroundStyle(tint)
                        }
                    Spacer()
                    if showsThumbnails {
                        HStack(spacing: -8) {
                            ForEach(Array(collection.items.prefix(2).enumerated()), id: \.offset) { _, item in
                                RoundedRectangle(cornerRadius: 7, style: .continuous)
                                    .fill(LinearGradient(
                                        colors: [Color(hue: item.thumbnailHue / 360, saturation: 0.18, brightness: 0.92),
                                                 Color(hue: ((item.thumbnailHue + 45).truncatingRemainder(dividingBy: 360)) / 360, saturation: 0.45, brightness: 0.72)],
                                        startPoint: .topLeading, endPoint: .bottomTrailing))
                                    .frame(width: 22, height: 22)
                            }
                        }
                    }
                }
                Text(collection.name)
                    .font(.system(size: 14.5, weight: .semibold))
                    .foregroundStyle(LNColor.primaryText)
                    .lineLimit(1)
                    .padding(.top, showsThumbnails ? 13 : 11)
                Text("\(collection.activeItemCount) items")
                    .font(LNFont.meta)
                    .foregroundStyle(LNColor.secondaryText)
                    .padding(.top, 2)
            }
            .padding(showsThumbnails ? 15 : 14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(LNColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: showsThumbnails ? 18 : LNRadius.cardLarge, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CardShadow())
        .accessibilityLabel("\(collection.name), \(collection.activeItemCount) items")
    }
}
