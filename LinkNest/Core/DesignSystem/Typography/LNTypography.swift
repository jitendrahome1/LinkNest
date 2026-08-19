//
//  LNTypography.swift
//  Typography tokens mapped 1:1 from the prototype's type scale.
//  System font (SF Pro) throughout; sizes support Dynamic Type via relativeTo.
//

import SwiftUI

enum LNFont {
    /// 28 / 800 — screen large titles ("Saved", "Collections")
    static let screenTitle = Font.system(size: 28, weight: .heavy).leading(.tight)
    /// 24 / 700 — Home greeting
    static let greeting = Font.system(size: 24, weight: .bold)
    /// 20–21 / 700–800 — detail titles, collection headers
    static let title = Font.system(size: 21, weight: .bold)
    /// 19 / 700 — sheet titles
    static let sheetTitle = Font.system(size: 19, weight: .bold)
    /// 17 / 700 — section headers
    static let sectionHeader = Font.system(size: 17, weight: .bold)
    /// 16 / 600 — primary buttons
    static let button = Font.system(size: 16, weight: .semibold)
    /// 15 — body, list rows, inputs
    static let body = Font.system(size: 15)
    /// 15 / 600 — row titles in sheets
    static let rowTitle = Font.system(size: 15, weight: .semibold)
    /// 14 / 600 — card titles
    static let cardTitle = Font.system(size: 14, weight: .semibold)
    /// 13.5–14 — secondary body
    static let callout = Font.system(size: 14)
    /// 13 / 600 uppercase — section labels ("MY NOTES", "COLLECTION")
    static let sectionLabel = Font.system(size: 13, weight: .semibold)
    /// 13 / 500 — chips, links ("See All")
    static let chip = Font.system(size: 13, weight: .medium)
    /// 12 — card metadata
    static let meta = Font.system(size: 12)
    /// 11 — stat captions, quick-action labels
    static let caption = Font.system(size: 11, weight: .medium)
    /// 10.5–11 — timestamps, tag strings
    static let micro = Font.system(size: 10.5)
    /// 10 / 500 — tab bar labels
    static let tabLabel = Font.system(size: 10, weight: .medium)
}
