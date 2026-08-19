//
//  LNColors.swift
//  Semantic color tokens. Values are the source-of-truth hex/alpha pairs
//  from the approved prototype (LinkNest.dc.html) — do not hardcode colors
//  elsewhere in the app.
//

import SwiftUI

extension Color {
    /// Dynamic color helper (light / dark providers).
    init(light: Color, dark: Color) {
        self.init(uiColor: UIColor { trait in
            trait.userInterfaceStyle == .dark ? UIColor(dark) : UIColor(light)
        })
    }

    init(hex: UInt32, alpha: Double = 1) {
        self.init(.sRGB,
                  red: Double((hex >> 16) & 0xFF) / 255,
                  green: Double((hex >> 8) & 0xFF) / 255,
                  blue: Double(hex & 0xFF) / 255,
                  opacity: alpha)
    }
}

enum LNColor {
    // Brand
    static let accent = Color(light: Color(hex: 0x4A50DB), dark: Color(hex: 0x8E93F2))
    static let accentSoft = Color(light: Color(hex: 0x4A50DB, alpha: 0.11), dark: Color(hex: 0x8E93F2, alpha: 0.22))

    // Surfaces
    static let background = Color(light: Color(hex: 0xF4F4F8), dark: Color(hex: 0x0E0E14))
    static let secondaryBackground = Color(light: Color(hex: 0xECECF1), dark: Color(hex: 0x16161D))
    static let cardBackground = Color(light: Color(hex: 0xFFFFFF), dark: Color(hex: 0x1B1B24))
    static let chip = Color(light: Color(hex: 0x78788C, alpha: 0.10), dark: Color(hex: 0xEBEBF5, alpha: 0.09))
    static let tabBar = Color(light: Color(hex: 0xFFFFFF, alpha: 0.80), dark: Color(hex: 0x13131B, alpha: 0.80))

    // Text
    static let primaryText = Color(light: Color(hex: 0x14141C), dark: Color(hex: 0xF2F2F7))
    static let secondaryText = Color(light: Color(hex: 0x3C3C48, alpha: 0.62), dark: Color(hex: 0xEBEBF5, alpha: 0.62))
    static let tertiaryText = Color(light: Color(hex: 0x3C3C48, alpha: 0.35), dark: Color(hex: 0xEBEBF5, alpha: 0.32))

    // Semantic
    static let destructive = Color(light: Color(hex: 0xDE4A50), dark: Color(hex: 0xF26B70))
    static let success = Color(light: Color(hex: 0x2E9E5B), dark: Color(hex: 0x4FBE7C))
    static let warning = Color(light: Color(hex: 0xC4880F), dark: Color(hex: 0xE0A63A))
    static let separator = Color(light: Color(hex: 0x3C3C48, alpha: 0.12), dark: Color(hex: 0xEBEBF5, alpha: 0.13))
}
