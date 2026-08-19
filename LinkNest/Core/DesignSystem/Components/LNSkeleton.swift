//
//  LNSkeleton.swift
//  Pulsing skeleton placeholders (metadata fetch, future loading states).
//

import SwiftUI

struct SkeletonPulse: ViewModifier {
    @State private var dimmed = false

    func body(content: Content) -> some View {
        content
            .opacity(dimmed ? 0.45 : 1)
            .animation(.easeInOut(duration: 0.6).repeatForever(autoreverses: true), value: dimmed)
            .onAppear { dimmed = true }
            .accessibilityLabel(String(localized: "a11y.loading", defaultValue: "Loading"))
    }
}

struct SkeletonBar: View {
    var width: CGFloat? = nil
    var height: CGFloat = 11

    var body: some View {
        RoundedRectangle(cornerRadius: height / 2, style: .continuous)
            .fill(LNColor.chip)
            .frame(width: width, height: height)
    }
}

/// Metadata-fetch skeleton card from the Save flow.
struct ContentCardSkeleton: View {
    var body: some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(LNColor.chip)
                .frame(width: 104, height: 70)
            VStack(alignment: .leading, spacing: 8) {
                SkeletonBar()
                SkeletonBar(width: 140)
                SkeletonBar(width: 80, height: 9)
            }
            Spacer(minLength: 0)
        }
        .padding(12)
        .background(LNColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: LNRadius.cardLarge, style: .continuous))
        .modifier(SkeletonPulse())
    }
}
