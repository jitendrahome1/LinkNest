//
//  ThumbnailView.swift
//  Gradient placeholder thumbnail with platform monogram + duration badge,
//  exactly as in the prototype (135° gradient driven by a stored hue).
//  Swaps to a real image once thumbnailURL is populated.
//

import SwiftUI

struct ThumbnailView: View {
    var hue: Double
    var platform: ContentPlatform
    var duration: String?
    var thumbnailURL: String?
    var cornerRadius: CGFloat = LNRadius.thumbnail
    var badgeScale: CGFloat = 1
    /// When .pdf, the corner badge reads "PDF" instead of the platform monogram.
    var contentType: ContentType = .other

    var body: some View {
        ZStack(alignment: .bottom) {
            gradient
            HStack {
                if contentType == .pdf {
                    badge(text: "PDF", background: Color(hex: 0xB3443C))
                } else {
                    badge(text: platform.monogram, background: Color(hex: platform.badgeHex))
                }
                Spacer()
                if let duration {
                    badge(text: duration, background: Color(hex: 0x0A0A10, alpha: 0.55))
                }
            }
            .padding(6 * badgeScale)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var gradient: some View {
        if let thumbnailURL, let url = URL(string: thumbnailURL) {
            AsyncImage(url: url) { image in
                image.resizable().aspectRatio(contentMode: .fill)
            } placeholder: {
                gradientFill
            }
        } else {
            gradientFill
        }
    }

    private var gradientFill: some View {
        LinearGradient(
            colors: [
                Color(hue: hue / 360, saturation: 0.18, brightness: 0.92),
                Color(hue: ((hue + 45).truncatingRemainder(dividingBy: 360)) / 360, saturation: 0.45, brightness: 0.72)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func badge(text: String, background: Color) -> some View {
        Text(text)
            .font(.system(size: 8.5 * badgeScale, weight: .bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 5 * badgeScale)
            .frame(height: 16 * badgeScale)
            .background(background, in: RoundedRectangle(cornerRadius: 4 * badgeScale, style: .continuous))
    }
}
