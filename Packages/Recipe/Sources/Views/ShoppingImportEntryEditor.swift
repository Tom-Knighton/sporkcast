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
        highlightedIngredientText(
            for: descriptor(from: ingredient),
            scale: scale,
            tint: tint
        )
    }

    public static func highlightedIngredientText(
        for ingredient: RecipeIngredient,
        scale: Double,
        tint: Color = .mint
    ) -> AttributedString {
        highlightedIngredientText(
            for: descriptor(from: ingredient),
            scale: scale,
            tint: tint
        )
    }

    public static func scaledIngredientText<Ingredient: ShoppingImportIngredientRepresentable>(
        for ingredient: Ingredient,
        scale: Double
    ) -> String {
        scaledIngredientText(for: descriptor(from: ingredient), scale: scale)
    }

    public static func scaledIngredientText(
        for ingredient: RecipeIngredient,
        scale: Double
    ) -> String {
        scaledIngredientText(for: descriptor(from: ingredient), scale: scale)
    }

    public static func scaledQuantityText(
        for ingredient: RecipeIngredient,
        scale: Double
    ) -> String? {
        scaledQuantityText(for: descriptor(from: ingredient), scale: scale)
    }

    public static func formatScale(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return String(format: "%.2f", value)
            .replacingOccurrences(of: #"\.?0+$"#, with: "", options: .regularExpression)
    }
}

private extension ShoppingImportIngredientFormatter {
    struct IngredientScaleDescriptor {
        let id: UUID
        let sortIndex: Int
        let ingredientText: String
        let ingredientPart: String?
        let extraInformation: String?
        let quantity: Double?
        let quantityText: String?
        let unitText: String?
        let emoji: String?
        let owned: Bool?
    }

    static func descriptor<Ingredient: ShoppingImportIngredientRepresentable>(
        from ingredient: Ingredient
    ) -> IngredientScaleDescriptor {
        IngredientScaleDescriptor(
            id: ingredient.ingredientId,
            sortIndex: 0,
            ingredientText: ingredient.ingredientText,
            ingredientPart: ingredient.ingredientPart,
            extraInformation: nil,
            quantity: ingredient.quantity,
            quantityText: ingredient.quantityText,
            unitText: ingredient.unitText,
            emoji: nil,
            owned: nil
        )
    }

    static func descriptor(from ingredient: RecipeIngredient) -> IngredientScaleDescriptor {
        IngredientScaleDescriptor(
            id: ingredient.id,
            sortIndex: ingredient.sortIndex,
            ingredientText: ingredient.ingredientText,
            ingredientPart: ingredient.ingredientPart,
            extraInformation: ingredient.extraInformation,
            quantity: ingredient.quantity?.quantity,
            quantityText: ingredient.quantity?.quantityText,
            unitText: ingredient.unit?.unitText,
            emoji: ingredient.emoji,
            owned: ingredient.owned
        )
    }

    static func highlightedIngredientText(
        for descriptor: IngredientScaleDescriptor,
        scale: Double,
        tint: Color
    ) -> AttributedString {
        let scaledText = scaledIngredientText(for: descriptor, scale: scale)
        let scaledQuantityText = scaledQuantityText(for: descriptor, scale: scale)
        let scaledQuantity = descriptor.quantity.map { $0 * scale }

        return IngredientHighlighter.highlight(
            ingredient: RecipeIngredient(
                id: descriptor.id,
                sortIndex: descriptor.sortIndex,
                ingredientText: scaledText,
                ingredientPart: descriptor.ingredientPart,
                extraInformation: descriptor.extraInformation,
                quantity: scaledQuantity.map {
                    IngredientQuantity(quantity: $0, quantityText: scaledQuantityText)
                },
                unit: descriptor.unitText.map {
                    IngredientUnit(unit: $0, unitText: $0)
                },
                emoji: descriptor.emoji,
                owned: descriptor.owned
            ),
            tint: tint
        )
    }

    static func scaledIngredientText(
        for descriptor: IngredientScaleDescriptor,
        scale: Double
    ) -> String {
        let source = descriptor.ingredientText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard
            !source.isEmpty,
            let quantity = descriptor.quantity,
            let originalQuantityText = descriptor.quantityText?.trimmingCharacters(in: .whitespacesAndNewlines),
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

    static func scaledQuantityText(
        for descriptor: IngredientScaleDescriptor,
        scale: Double
    ) -> String? {
        guard let quantity = descriptor.quantity else { return nil }
        return formatScale(quantity * scale)
    }
}
