//
//  LinkNestPDFSearch.swift
//  In-document search bar: text field + "N of M results" + prev/next/close,
//  built from the same field/chip language as LNSearchBar and LNIconButton.
//

import SwiftUI

struct LinkNestPDFSearch: View {
    @Binding var query: String
    var resultCount: Int
    var currentIndex: Int
    var isSearching: Bool
    var onPrevious: () -> Void
    var onNext: () -> Void
    var onClose: () -> Void
    @FocusState.Binding var isFocused: Bool

    private var resultLabel: String {
        if isSearching {
            return String(localized: "pdf.searching", defaultValue: "Searching…")
        }
        guard !query.trimmingCharacters(in: .whitespaces).isEmpty else { return "" }
        guard resultCount > 0 else {
            return String(localized: "pdf.noResults", defaultValue: "No results")
        }
        return String(localized: "pdf.resultCount",
                      defaultValue: "\(currentIndex + 1) of \(resultCount)")
    }

    var body: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(LNColor.tertiaryText)
                TextField(String(localized: "pdf.searchPlaceholder", defaultValue: "Search in document"),
                          text: $query)
                    .font(LNFont.body)
                    .foregroundStyle(LNColor.primaryText)
                    .focused($isFocused)
                    .submitLabel(.search)
                if !resultLabel.isEmpty {
                    Text(resultLabel)
                        .font(.system(size: 11.5, weight: .medium))
                        .foregroundStyle(LNColor.tertiaryText)
                        .lineLimit(1)
                        .fixedSize()
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 40)
            .background(LNColor.chip, in: RoundedRectangle(cornerRadius: 12, style: .continuous))

            HStack(spacing: 4) {
                Button(action: onPrevious) {
                    Image(systemName: "chevron.up")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(resultCount > 0 ? LNColor.primaryText : LNColor.tertiaryText)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(resultCount == 0)
                .accessibilityLabel(String(localized: "pdf.previousResult", defaultValue: "Previous result"))

                Button(action: onNext) {
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(resultCount > 0 ? LNColor.primaryText : LNColor.tertiaryText)
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.plain)
                .disabled(resultCount == 0)
                .accessibilityLabel(String(localized: "pdf.nextResult", defaultValue: "Next result"))
            }

            Button(String(localized: "search.cancel", defaultValue: "Cancel"), action: onClose)
                .font(.system(size: 14.5, weight: .medium))
                .foregroundStyle(LNColor.accent)
                .buttonStyle(.plain)
        }
        .padding(.horizontal, LNSpacing.gutter)
        .padding(.vertical, 8)
        .background(LNColor.background)
    }
}
