//
//  LinkNestPlayerProgressBar.swift
//  Thin accent-fill scrub bar with a white knob, per the Content Viewer
//  prototype. Domain-agnostic — VideoPlayerView drives it with playback
//  time, PDFReaderView with page position. Supports tap-to-seek and drag.
//

import SwiftUI

struct LinkNestPlayerProgressBar: View {
    /// 0...1. Reflects live drag position while scrubbing.
    var progress: Double
    var leadingLabel: String? = nil
    var trailingLabel: String? = nil
    /// Fires continuously while dragging, and once more on release.
    var onScrub: (Double) -> Void
    var onDone: (() -> Void)? = nil
    var trackTint = Color.white
    var labelTint: Color = LNColor.tertiaryText

    @State private var dragFraction: Double?

    private var displayed: Double { min(1, max(0, dragFraction ?? progress)) }

    var body: some View {
        VStack(spacing: 2) {
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LNColor.chip)
                        .frame(height: 6)
                    Capsule()
                        .fill(LNColor.accent)
                        .frame(width: geo.size.width * displayed, height: 6)
                        .shadow(color: LNColor.accent.opacity(0.55), radius: 4, y: 0)
                    Circle()
                        .fill(trackTint)
                        .frame(width: 15, height: 15)
                        .overlay {
                            Circle().strokeBorder(.black.opacity(0.08), lineWidth: 0.5)
                        }
                        .shadow(color: .black.opacity(0.35), radius: 4, y: 1.5)
                        .offset(x: geo.size.width * displayed - 7.5)
                }
                .frame(height: geo.size.height)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let fraction = min(1, max(0, value.location.x / geo.size.width))
                            dragFraction = fraction
                            onScrub(fraction)
                        }
                        .onEnded { value in
                            let fraction = min(1, max(0, value.location.x / geo.size.width))
                            onScrub(fraction)
                            dragFraction = nil
                            onDone?()
                        }
                )
            }
            .frame(height: 24)

            if leadingLabel != nil || trailingLabel != nil {
                HStack {
                    Text(leadingLabel ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(labelTint)
                    Spacer()
                    Text(trailingLabel ?? "")
                        .font(.system(size: 11))
                        .foregroundStyle(labelTint)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "a11y.scrub", defaultValue: "Progress"))
        .accessibilityValue("\(Int(displayed * 100))%")
        .accessibilityAdjustableAction { direction in
            let step = 0.02
            switch direction {
            case .increment: onScrub(min(1, displayed + step))
            case .decrement: onScrub(max(0, displayed - step))
            @unknown default: break
            }
            onDone?()
        }
    }
}
