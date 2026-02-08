//
//  EditIngredientRow.swift
//  Recipe
//
//  Created by Tom Knighton on 16/01/2026.
//

import SwiftUI
import Models
import Design
import Environment

struct IngredientRow: View {
    @Binding var ingredient: RecipeIngredient
    @State private var attributed: AttributedString = ""
    let tint: Color
    let focusedID: FocusState<UUID?>.Binding
    
    var body: some View {
        HStack {
            EmojiPickerButton(emoji: $ingredient.emoji)
            
            Text(attributed)
                .opacity(0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: attributed) { _, newValue in
                    let v = String(newValue.characters)
                    ingredient.ingredientText = v
                    self.parseIngredientText(v)
                }
                .onChange(of: ingredient, initial: true) { _, newValue in
                    attributed = IngredientHighlighter.highlight(
                        ingredient: ingredient,
                        font: .body,
                        tint: .secondary
                    )
                }
                .overlay {
                    TextEditor(text: $attributed)
                        .padding(.horizontal, -4)
                        .padding(.vertical, -10)
                        .scrollDisabled(true)
                        .submitLabel(.done)
                        .focused(focusedID, equals: ingredient.id)
                }
            
            Image(systemName: "line.3.horizontal")
        }
    }
    
    private func parseIngredientText(_ text: String) {
        let attributed = try? parseIngredient(text, "en")
        self.ingredient.ingredientText = text
        if let attributed {
            ingredient.quantity = .init(quantity: attributed.quantity, quantityText: attributed.quantityText)
            ingredient.unit = .init(unit: attributed.unit, unitText: attributed.unitText)
            ingredient.ingredientPart = attributed.ingredient
            ingredient.extraInformation = attributed.extra
        }
    }
}
