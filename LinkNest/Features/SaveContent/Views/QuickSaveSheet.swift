//
//  QuickSaveSheet.swift
//  Bottom sheet from the tab bar's center plus button.
//

import SwiftUI

struct QuickSaveSheet: View {
    @Environment(AppState.self) private var appState
    @Environment(AppRouter.self) private var router
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "quick.title", defaultValue: "Save Something"))
                .font(LNFont.sheetTitle)
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 16)
            Text(String(localized: "quick.subtitle", defaultValue: "Add a link to your library in seconds."))
                .font(.system(size: 13))
                .foregroundStyle(LNColor.secondaryText)
                .padding(.top, 4)

            VStack(spacing: 8) {
                QuickOption(systemImage: "link",
                            title: String(localized: "quick.paste", defaultValue: "Paste Link"),
                            subtitle: String(localized: "quick.pasteSub", defaultValue: "Enter or paste any URL")) {
                    dismiss()
                    router.push(.saveLink(prefill: nil))
                }
                QuickOption(systemImage: "doc.on.clipboard",
                            title: String(localized: "quick.clipboard", defaultValue: "From Clipboard"),
                            subtitle: UIPasteboard.general.string ?? "youtube.com/watch?v=8kZ…") {
                    dismiss()
                    router.push(.saveLink(prefill: UIPasteboard.general.string ?? "https://www.youtube.com/watch?v=8kZq3xB"))
                }
                QuickOption(systemImage: "square.and.arrow.up",
                            title: String(localized: "quick.share", defaultValue: "Share from Another App"),
                            subtitle: String(localized: "quick.shareSub", defaultValue: "Use the LinkNest share extension")) {
                    dismiss()
                    appState.showToast(String(localized: "toast.shareExt", defaultValue: "Enable LinkNest in the iOS share sheet"))
                }
                QuickOption(systemImage: "pencil",
                            title: String(localized: "quick.manual", defaultValue: "Add Manually"),
                            subtitle: String(localized: "quick.manualSub", defaultValue: "Type the details yourself")) {
                    dismiss()
                    router.push(.saveLink(prefill: nil))
                }
            }
            .padding(.top, 14)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LNSpacing.gutter)
        .background(LNColor.background)
        .presentationDetents([.height(420)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(LNRadius.sheet)
    }
}

private struct QuickOption: View {
    var systemImage: String
    var title: String
    var subtitle: String
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                RoundedRectangle(cornerRadius: LNRadius.iconTile, style: .continuous)
                    .fill(LNColor.accentSoft)
                    .frame(width: 40, height: 40)
                    .overlay {
                        Image(systemName: systemImage)
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(LNColor.accent)
                    }
                VStack(alignment: .leading, spacing: 1) {
                    Text(title)
                        .font(LNFont.rowTitle)
                        .foregroundStyle(LNColor.primaryText)
                    Text(subtitle)
                        .font(LNFont.meta)
                        .foregroundStyle(LNColor.secondaryText)
                        .lineLimit(1)
                }
                Spacer()
                Image(systemName: "chevron.right")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(LNColor.tertiaryText)
            }
            .padding(EdgeInsets(top: 13, leading: 14, bottom: 13, trailing: 14))
            .background(LNColor.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 15, style: .continuous))
        }
        .buttonStyle(.plain)
        .modifier(CardShadow())
        .accessibilityLabel(title)
        .accessibilityHint(subtitle)
    }
}
