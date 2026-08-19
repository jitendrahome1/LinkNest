//
//  LNTokens.swift
//  Spacing, corner radius, shadow, icon-size and animation tokens
//  extracted from the approved prototype.
//

import SwiftUI

enum LNSpacing {
    static let xs: CGFloat = 4
    static let s: CGFloat = 8
    static let m: CGFloat = 12
    static let l: CGFloat = 16
    /// Horizontal screen margin (prototype uses 18pt gutters)
    static let gutter: CGFloat = 18
    static let xl: CGFloat = 24
    static let sectionGap: CGFloat = 22
}

enum LNRadius {
    static let chip: CGFloat = 16
    static let field: CGFloat = 12
    static let button: CGFloat = 14
    static let card: CGFloat = 14
    static let cardLarge: CGFloat = 16
    static let statCard: CGFloat = 18
    static let hero: CGFloat = 20
    static let sheet: CGFloat = 26
    static let iconTile: CGFloat = 13
    static let thumbnail: CGFloat = 10
}

enum LNShadow {
    /// Subtle card elevation: 0 1 3 rgba(20,20,40,0.05)
    static func card<V: View>(_ view: V) -> some View {
        view.shadow(color: Color(hex: 0x141428, alpha: 0.05), radius: 3, y: 1)
    }
    /// Accent glow under primary CTAs and the tab-bar plus button
    static func accentGlow<V: View>(_ view: V) -> some View {
        view.shadow(color: LNColor.accent.opacity(0.32), radius: 14, y: 8)
    }
}

enum LNIconSize {
    static let tab: CGFloat = 23
    static let action: CGFloat = 17
    static let inline: CGFloat = 15
    static let quickAction: CGFloat = 21
    static let empty: CGFloat = 44
}

enum LNAnimation {
    /// Sheet / toast entrance
    static let sheet = Animation.spring(response: 0.32, dampingFraction: 0.86)
    /// Chip & segment selection
    static let selection = Animation.easeOut(duration: 0.15)
    /// Toggle knobs
    static let toggle = Animation.easeOut(duration: 0.2)
    /// Onboarding pager
    static let pager = Animation.timingCurve(0.3, 0.8, 0.3, 1, duration: 0.45)
}
