//
//  OnboardingView.swift
//  Three pages with the prototype's illustration compositions,
//  pill page indicators, Continue / Get Started CTA and Sign In escape.
//

import SwiftUI

struct OnboardingView: View {
    @Environment(AppState.self) private var appState
    @State private var page = 0

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Spacer()
                Button(String(localized: "onboarding.skip", defaultValue: "Skip")) { finish(signup: false) }
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LNColor.secondaryText)
                    .buttonStyle(.plain)
            }
            .padding(.horizontal, 22)
            .padding(.top, 10)

            TabView(selection: $page) {
                OnboardingPage(illustration: { CollectIllustration() },
                               title: String(localized: "onboarding.p1.title", defaultValue: "Save Anything Useful"),
                               message: String(localized: "onboarding.p1.body", defaultValue: "Save videos, articles, posts and websites from anywhere."))
                    .tag(0)
                OnboardingPage(illustration: { OrganizeIllustration() },
                               title: String(localized: "onboarding.p2.title", defaultValue: "Organize Your Knowledge"),
                               message: String(localized: "onboarding.p2.body", defaultValue: "Use collections, tags and smart filters to keep everything easy to find."))
                    .tag(1)
                OnboardingPage(illustration: { FindIllustration() },
                               title: String(localized: "onboarding.p3.title", defaultValue: "Find It When You Need It"),
                               message: String(localized: "onboarding.p3.body", defaultValue: "Search your saved content in seconds and never lose a useful discovery again."))
                    .tag(2)
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
            .animation(LNAnimation.pager, value: page)

            HStack(spacing: 7) {
                ForEach(0..<3) { index in
                    Capsule()
                        .fill(index == page ? LNColor.accent : LNColor.tertiaryText)
                        .frame(width: index == page ? 22 : 8, height: 8)
                        .animation(.easeOut(duration: 0.3), value: page)
                }
            }
            .padding(.bottom, 22)
            .accessibilityLabel("Page \(page + 1) of 3")

            LNPrimaryButton(title: page < 2
                ? String(localized: "onboarding.continue", defaultValue: "Continue")
                : String(localized: "onboarding.getStarted", defaultValue: "Get Started")) {
                if page < 2 { page += 1 } else { finish(signup: true) }
            }
            .padding(.horizontal, 26)
            .modifier(AccentGlow())

            HStack(spacing: 4) {
                Text(String(localized: "onboarding.hasAccount", defaultValue: "Already have an account?"))
                    .foregroundStyle(LNColor.secondaryText)
                Button(String(localized: "onboarding.signIn", defaultValue: "Sign In")) { finish(signup: false) }
                    .foregroundStyle(LNColor.accent)
                    .fontWeight(.semibold)
                    .buttonStyle(.plain)
            }
            .font(.system(size: 14))
            .padding(.top, 15)
            .padding(.bottom, 18)
        }
        .background(LNColor.background)
    }

    private func finish(signup: Bool) {
        appState.hasOnboarded = true
        NotificationCenter.default.post(name: .authModeRequest, object: signup ? "signup" : "signin")
        appState.phase = .auth
    }
}

extension Notification.Name {
    static let authModeRequest = Notification.Name("linknest.authModeRequest")
}

struct AccentGlow: ViewModifier {
    func body(content: Content) -> some View {
        content.shadow(color: LNColor.accent.opacity(0.3), radius: 10, y: 8)
    }
}

private struct OnboardingPage<Illustration: View>: View {
    @ViewBuilder var illustration: Illustration
    var title: String
    var message: String

    var body: some View {
        VStack(spacing: 0) {
            illustration
                .frame(height: 270)
            Text(title)
                .font(.system(size: 25, weight: .heavy))
                .kerning(-0.5)
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 30)
            Text(message)
                .font(.system(size: 15))
                .foregroundStyle(LNColor.secondaryText)
                .multilineTextAlignment(.center)
                .lineSpacing(4)
                .padding(.top, 10)
                .padding(.horizontal, 36)
            Spacer()
        }
        .padding(.top, 26)
    }
}

// MARK: - Illustrations (compositions of cards/tiles, as in the prototype)

private struct MiniLinkCard: View {
    var monogram: String
    var color: Color
    var rotation: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(monogram)
                .font(.system(size: 8, weight: .bold))
                .foregroundStyle(.white)
                .frame(width: 26, height: 14)
                .background(color, in: RoundedRectangle(cornerRadius: 4))
            SkeletonBar(width: 78, height: 7)
            SkeletonBar(width: 52, height: 7)
        }
        .padding(10)
        .frame(width: 118, height: 62, alignment: .topLeading)
        .background(LNColor.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color(hex: 0x141428, alpha: 0.13), radius: 12, y: 8)
        .rotationEffect(.degrees(rotation))
    }
}

private struct CollectIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 26, style: .continuous)
                .fill(LNColor.accentSoft)
                .frame(width: 196, height: 98)
                .offset(y: 86)
            Image(systemName: "link")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(LNColor.accent)
                .offset(y: 96)
            MiniLinkCard(monogram: "YT", color: Color(hex: 0xC93F38), rotation: -9)
                .offset(x: -104, y: 30)
            MiniLinkCard(monogram: "in", color: Color(hex: 0x20679E), rotation: 10)
                .offset(x: 104, y: 34)
            MiniLinkCard(monogram: "IG", color: Color(hex: 0xB23A80), rotation: 2)
                .offset(y: -22)
        }
        .accessibilityHidden(true)
    }
}

private struct OrganizeIllustration: View {
    private let tiles: [(String, UInt32)] = [("i", 0x4A50DB), ("A", 0x7A3FD1), ("D", 0xC74B78), ("C", 0x0E8A8A)]

    var body: some View {
        LazyVGrid(columns: [GridItem(.fixed(96)), GridItem(.fixed(96))], spacing: 14) {
            ForEach(tiles, id: \.0) { initial, hex in
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(Color(hex: hex, alpha: 0.13))
                    .frame(width: 96, height: 96)
                    .overlay {
                        Text(initial)
                            .font(.system(size: 26, weight: .heavy))
                            .foregroundStyle(Color(hex: hex))
                    }
            }
        }
        .accessibilityHidden(true)
    }
}

private struct FindIllustration: View {
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LNColor.cardBackground)
                .frame(width: 110, height: 58)
                .shadow(color: Color(hex: 0x141428, alpha: 0.1), radius: 9, y: 6)
                .rotationEffect(.degrees(-6))
                .offset(x: -92, y: -58)
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(LNColor.cardBackground)
                .frame(width: 110, height: 58)
                .shadow(color: Color(hex: 0x141428, alpha: 0.1), radius: 9, y: 6)
                .rotationEffect(.degrees(5))
                .offset(x: 92, y: -64)
            Circle()
                .fill(LNColor.accent)
                .frame(width: 104, height: 104)
                .overlay {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 38, weight: .medium))
                        .foregroundStyle(.white)
                }
                .shadow(color: LNColor.accent.opacity(0.35), radius: 20, y: 18)
            HStack(spacing: 8) {
                ForEach(["#SwiftUI", "#AI", "#Design"], id: \.self) { tag in
                    Text(tag)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(LNColor.accent)
                        .padding(.horizontal, 12)
                        .frame(height: 28)
                        .background(LNColor.accentSoft, in: Capsule())
                }
            }
            .offset(y: 96)
        }
        .accessibilityHidden(true)
    }
}
