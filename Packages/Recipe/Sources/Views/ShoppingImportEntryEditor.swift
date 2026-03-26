//
//  ShoppingImportEntryEditor.swift
//  Recipe
//
//  Created by Tom Knighton on 23/03/2026.
//

import SwiftUI
import Models

public protocol ShoppingImportIngredientRepresentable: Identifiable where ID == UUID {
    var ingredientId: UUID { get }
    var ingredientText: String { get }
    var ingredientPart: String? { get }
    var quantity: Double? { get }
    var quantityText: String? { get }
    var unitText: String? { get }
    var isSelected: Bool { get set }
}

public protocol ShoppingImportEntryRepresentable: Identifiable where ID == UUID {
    associatedtype Ingredient: ShoppingImportIngredientRepresentable
    var isSelected: Bool { get set }
    var scale: Double { get set }
    var ingredients: [Ingredient] { get set }
}

public struct ShoppingImportEntryEditor<Entry: ShoppingImportEntryRepresentable>: View {
    @Binding private var entry: Entry

    private let includeToggleTitle: String
    private let tint: Color

    public init(
        entry: Binding<Entry>,
        includeToggleTitle: String = "Include recipe",
        tint: Color = .mint
    ) {
        self._entry = entry
        self.includeToggleTitle = includeToggleTitle
        self.tint = tint
    }

    public var body: some View {
        Toggle(includeToggleTitle, isOn: $entry.isSelected)

        Stepper(value: $entry.scale, in: 0.25...4.0, step: 0.25) {
            Text("Scale \(ShoppingImportIngredientFormatter.formatScale(entry.scale))x")
        }
        .disabled(!entry.isSelected)

        ForEach($entry.ingredients) { $ingredient in
            Toggle(
                isOn: Binding(
                    get: { ingredient.isSelected },
                    set: { newValue in
                        ingredient.isSelected = newValue
                        if newValue {
                            entry.isSelected = true
                        }
                    }
                ),
                label: {
                    Text(
                        ShoppingImportIngredientFormatter.highlightedIngredientText(
                            for: ingredient,
                            scale: entry.scale,
                            tint: tint
                        )
                    )
                    .font(.body)
                }
            )
            .disabled(!entry.isSelected)
        }
    }
}

public enum ShoppingImportIngredientFormatter {
    public static func highlightedIngredientText<Ingredient: ShoppingImportIngredientRepresentable>(
        for ingredient: Ingredient,
        scale: Double,
        tint: Color = .mint
    ) -> AttributedString {
        let scaledText = scaledIngredientText(for: ingredient, scale: scale)
        let scaledQuantity = ingredient.quantity.map { $0 * scale }
        let scaledQuantityText = scaledQuantity.map(formatScale)

        return IngredientHighlighter.highlight(
            ingredient: RecipeIngredient(
                id: ingredient.ingredientId,
                sortIndex: 0,
                ingredientText: scaledText,
                ingredientPart: ingredient.ingredientPart,
                extraInformation: nil,
                quantity: scaledQuantity.map {
                    IngredientQuantity(quantity: $0, quantityText: scaledQuantityText)
                },
                unit: ingredient.unitText.map {
                    IngredientUnit(unit: $0, unitText: $0)
                },
                emoji: nil,
                owned: nil
            ),
            tint: tint
        )
    }

    public static func scaledIngredientText<Ingredient: ShoppingImportIngredientRepresentable>(
        for ingredient: Ingredient,
        scale: Double
    ) -> String {
        let source = ingredient.ingredientText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !source.isEmpty,
            let quantity = ingredient.quantity,
            let originalQuantityText = ingredient.quantityText?.trimmingCharacters(in: .whitespacesAndNewlines),
            !originalQuantityText.isEmpty
        else {
            return source
        }

        let scaledQuantityText = formatScale(quantity * scale)
        guard let quantityRange = source.range(of: originalQuantityText) else {
            return source
        }

        var updated = source
        updated.replaceSubrange(quantityRange, with: scaledQuantityText)
        return updated
    }

    public static func formatScale(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
}
