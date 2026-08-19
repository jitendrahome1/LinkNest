//
//  LinkNestPlayerControls.swift
//  The video player's center transport cluster (±10s, play/pause),
//  overlaid on the video box. Always the same translucent glass
//  treatment, since it always sits on top of live video pixels —
//  inline card or fullscreen alike.
//

import SwiftUI

struct LinkNestPlayerControls: View {
    var isPlaying: Bool
    var onTogglePlay: () -> Void
    var onSkipBack: () -> Void
    var onSkipForward: () -> Void

    var body: some View {
        HStack(spacing: 30) {
            skipButton(systemImage: "gobackward.10",
                       label: String(localized: "player.back10", defaultValue: "Back 10 seconds"),
                       action: onSkipBack)

            Button(action: onTogglePlay) {
                Circle()
                    .fill(LNColor.accent)
                    .frame(width: 64, height: 64)
                    .overlay {
                        Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                            .font(.system(size: 24, weight: .semibold))
                            .foregroundStyle(.white)
                            .offset(x: isPlaying ? 0 : 2)
                    }
                    .shadow(color: .black.opacity(0.35), radius: 14, y: 6)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(isPlaying
                ? String(localized: "player.pause", defaultValue: "Pause")
                : String(localized: "player.play", defaultValue: "Play"))
            .sensoryFeedback(.impact(weight: .light), trigger: isPlaying)

            skipButton(systemImage: "goforward.10",
                       label: String(localized: "player.forward10", defaultValue: "Forward 10 seconds"),
                       action: onSkipForward)
        }
    }

    private func skipButton(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Circle()
                .fill(.ultraThinMaterial)
                .environment(\.colorScheme, .dark)
                .frame(width: 46, height: 46)
                .overlay {
                    Image(systemName: systemImage)
                        .font(.system(size: 19, weight: .regular))
                        .foregroundStyle(.white)
                }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}

/// Scrub bar + time + speed/mute/PiP/fullscreen row. `.flat` sits in normal
/// flow below the inline video card (theme-aware chip styling, matching the
/// rest of the app); `.overlay` sits on top of the video in fullscreen.
struct LinkNestPlayerBottomBar: View {
    enum Style { case flat, overlay }

    var style: Style = .flat
    var progress: Double
    var positionLabel: String
    var durationLabel: String
    var speedLabel: String
    var isMuted: Bool
    var isPiPAvailable: Bool
    var isFullscreen: Bool

    var onScrub: (Double) -> Void
    var onScrubEnd: () -> Void
    var onSpeed: () -> Void
    var onToggleMute: () -> Void
    var onPiP: () -> Void
    var onToggleFullscreen: () -> Void

    private var isOverlay: Bool { style == .overlay }
    private var labelTint: Color { isOverlay ? .white.opacity(0.6) : LNColor.tertiaryText }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            LinkNestPlayerProgressBar(progress: progress,
                                      leadingLabel: positionLabel,
                                      trailingLabel: durationLabel,
                                      onScrub: onScrub,
                                      onDone: onScrubEnd,
                                      trackTint: isOverlay ? .white : .white,
                                      labelTint: labelTint)

            HStack(spacing: 8) {
                pill(label: speedLabel, action: onSpeed)
                    .accessibilityLabel(String(localized: "player.speed", defaultValue: "Playback Speed"))

                iconChip(systemImage: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill",
                         label: isMuted
                            ? String(localized: "player.unmute", defaultValue: "Unmute")
                            : String(localized: "player.mute", defaultValue: "Mute"),
                         action: onToggleMute)

                if isPiPAvailable {
                    iconChip(systemImage: "pip.enter",
                             label: String(localized: "player.pip", defaultValue: "Picture in Picture"),
                             action: onPiP)
                }

                Spacer()

                iconChip(systemImage: isFullscreen ? "arrow.down.right.and.arrow.up.left" : "arrow.up.left.and.arrow.down.right",
                         label: isFullscreen
                            ? String(localized: "player.exitFullscreen", defaultValue: "Exit Fullscreen")
                            : String(localized: "player.fullscreen", defaultValue: "Fullscreen"),
                         action: onToggleFullscreen)
            }
        }
    }

    private func pill(label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.system(size: 12.5, weight: .bold))
                .foregroundStyle(isOverlay ? .white : LNColor.primaryText)
                .padding(.horizontal, 10)
                .frame(height: 30)
                .frame(minWidth: 44)
                .background {
                    if isOverlay {
                        RoundedRectangle(cornerRadius: 15, style: .continuous)
                            .fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                    } else {
                        RoundedRectangle(cornerRadius: 15, style: .continuous).fill(LNColor.chip)
                    }
                }
        }
        .buttonStyle(.plain)
    }

    private func iconChip(systemImage: String, label: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Group {
                if isOverlay {
                    RoundedRectangle(cornerRadius: 15, style: .continuous)
                        .fill(.ultraThinMaterial).environment(\.colorScheme, .dark)
                } else {
                    RoundedRectangle(cornerRadius: 15, style: .continuous).fill(LNColor.chip)
                }
            }
            .frame(width: 30, height: 30)
            .overlay {
                Image(systemName: systemImage)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(isOverlay ? .white : LNColor.secondaryText)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
    }
}
