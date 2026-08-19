//
//  NewCollectionSheet.swift
//

import SwiftUI

struct NewCollectionSheet: View {
    @Environment(AppContainer.self) private var container
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var colorHex: UInt32 = CreateCollectionUseCase.palette[0]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(String(localized: "collections.new", defaultValue: "New Collection"))
                .font(LNFont.sheetTitle)
                .foregroundStyle(LNColor.primaryText)
                .padding(.top, 16)

            TextField(String(localized: "collections.namePlaceholder", defaultValue: "Collection name"), text: $name)
                .font(LNFont.body)
                .foregroundStyle(LNColor.primaryText)
                .padding(.horizontal, 15)
                .frame(height: 50)
                .background(LNColor.cardBackground, in: RoundedRectangle(cornerRadius: LNRadius.card, style: .continuous))
                .modifier(CardShadow())
                .padding(.top, 12)

            LNSectionLabel(text: String(localized: "collections.color", defaultValue: "Color"))
                .padding(.top, 16)
            HStack(spacing: 10) {
                ForEach(CreateCollectionUseCase.palette, id: \.self) { hex in
                    Button {
                        colorHex = hex
                    } label: {
                        Circle()
                            .fill(Color(hex: hex))
                            .frame(width: 34, height: 34)
                            .overlay {
                                if colorHex == hex {
                                    Circle().stroke(LNColor.background, lineWidth: 3).padding(2)
                                }
                            }
                            .overlay {
                                if colorHex == hex {
                                    Circle().stroke(Color(hex: hex), lineWidth: 2.5).padding(-3)
                                }
                            }
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Color option")
                    .accessibilityAddTraits(colorHex == hex ? .isSelected : [])
                }
            }
            .padding(.top, 10)

            LNPrimaryButton(title: String(localized: "collections.create", defaultValue: "Create Collection")) {
                container.createCollection(name: name, colorHex: colorHex)
                dismiss()
                appState.showToast(String(localized: "toast.collectionCreated", defaultValue: "Collection created"))
            }
            .padding(.top, 20)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, LNSpacing.gutter)
        .background(LNColor.background)
        .presentationDetents([.height(330)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(LNRadius.sheet)
    }
}
