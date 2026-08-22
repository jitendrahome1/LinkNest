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
    /// PDF page count, shown in the corner badge (e.g. "18p") in place of a
    /// duration — a PDF has no duration, so that badge used to just be blank,
    /// giving no sense of length at a glance.
    var pageCount: Int = 0

    var body: some View {
        ZStack {
            gradient
            // Real scraped thumbnails can have dense text baked into the
            // photo itself; a scrim keeps the badges legible over any image.
            if thumbnailURL != nil {
                LinearGradient(colors: [.clear, Color.black.opacity(0.45)],
                              startPoint: .center, endPoint: .bottom)
                    .allowsHitTesting(false)
            }
            // A centered, translucent kind icon makes video vs. PDF vs. plain
            // link legible at a glance, without reading any text — the
            // platform/duration corner badges alone left every thumbnail
            // (video, PDF, article) looking the same shape.
            centerKindIcon
        }
        .overlay(alignment: .bottom) {
            HStack {
                if contentType == .pdf {
                    badge(text: "PDF", background: Color(hex: 0xB3443C))
                } else {
                    badge(text: platform.monogram, background: Color(hex: platform.badgeHex))
                }
                Spacer()
                if let cornerBadgeText {
                    badge(text: cornerBadgeText, background: Color(hex: 0x0A0A10, alpha: 0.55))
                }
            }
            .padding(6 * badgeScale)
        }
        .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        .accessibilityHidden(true)
    }

    private var cornerBadgeText: String? {
        if contentType == .pdf {
            return pageCount > 0 ? "\(pageCount)p" : nil
        }
        return duration
    }

    @ViewBuilder
    private var centerKindIcon: some View {
        switch contentType {
        case .video:
            kindCircle {
                Image(systemName: "play.fill")
                    .offset(x: 1.5 * badgeScale)
            }
        case .pdf:
            kindCircle {
                Image(systemName: "doc.fill")
            }
        default:
            EmptyView()
        }
    }

    private func kindCircle(@ViewBuilder icon: () -> some View) -> some View {
        Circle()
            .fill(Color(hex: 0x0A0A10, alpha: 0.4))
            .frame(width: 38 * badgeScale, height: 38 * badgeScale)
            .overlay {
                icon()
                    .font(.system(size: 15 * badgeScale, weight: .semibold))
                    .foregroundStyle(.white)
            }
    }

    @ViewBuilder
    private var gradient: some View {
        if let thumbnailURL, let url = URL(string: thumbnailURL) {
            // AsyncImage doesn't reliably adopt an ancestor's proposed size
            // for a loaded image (it can size to the image's own pixel
            // dimensions instead) — pinning it to the GeometryReader's
            // resolved size is what actually forces it to match the
            // surrounding fixed-height frame instead of pushing sibling
            // views around.
            GeometryReader { geo in
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                } placeholder: {
                    gradientFill
                }
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
