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
        unitSystem: RecipeIngredientUnitSystem = .original,
        tint: Color = .mint
    ) -> AttributedString {
        highlightedIngredientText(
            for: descriptor(from: ingredient),
            scale: scale,
            unitSystem: unitSystem,
            tint: tint
        )
    }

    public static func highlightedIngredientText(
        for ingredient: RecipeIngredient,
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem = .original,
        tint: Color = .mint
    ) -> AttributedString {
        highlightedIngredientText(
            for: descriptor(from: ingredient),
            scale: scale,
            unitSystem: unitSystem,
            tint: tint
        )
    }

    public static func scaledIngredientText<Ingredient: ShoppingImportIngredientRepresentable>(
        for ingredient: Ingredient,
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem = .original
    ) -> String {
        scaledIngredientText(for: descriptor(from: ingredient), scale: scale, unitSystem: unitSystem)
    }

    public static func scaledIngredientText(
        for ingredient: RecipeIngredient,
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem = .original
    ) -> String {
        scaledIngredientText(for: descriptor(from: ingredient), scale: scale, unitSystem: unitSystem)
    }

    public static func scaledQuantityText(
        for ingredient: RecipeIngredient,
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem = .original
    ) -> String? {
        scaledQuantityText(for: descriptor(from: ingredient), scale: scale, unitSystem: unitSystem)
    }

    public static func scaledUnitText(
        for ingredient: RecipeIngredient,
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem = .original
    ) -> String? {
        scaledUnitText(for: descriptor(from: ingredient), scale: scale, unitSystem: unitSystem)
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
    enum IngredientUnitFamily {
        case mass
        case volume
    }

    enum CanonicalIngredientUnit {
        case gram
        case kilogram
        case ounce
        case pound
        case milliliter
        case liter
        case fluidOunce
        case cup
        case pint
        case quart
        case gallon

        var family: IngredientUnitFamily {
            switch self {
            case .gram, .kilogram, .ounce, .pound:
                return .mass
            case .milliliter, .liter, .fluidOunce, .cup, .pint, .quart, .gallon:
                return .volume
            }
        }

        var system: RecipeIngredientUnitSystem {
            switch self {
            case .gram, .kilogram, .milliliter, .liter:
                return .metric
            case .ounce, .pound, .fluidOunce, .cup, .pint, .quart, .gallon:
                return .imperial
            }
        }

        var displayText: String {
            switch self {
            case .gram:
                return "g"
            case .kilogram:
                return "kg"
            case .ounce:
                return "oz"
            case .pound:
                return "lb"
            case .milliliter:
                return "ml"
            case .liter:
                return "l"
            case .fluidOunce:
                return "fl oz"
            case .cup:
                return "cup"
            case .pint:
                return "pt"
            case .quart:
                return "qt"
            case .gallon:
                return "gal"
            }
        }
    }

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

    struct DisplayIngredientValues {
        let ingredientText: String
        let quantity: Double?
        let quantityText: String?
        let unitText: String?
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
        unitSystem: RecipeIngredientUnitSystem,
        tint: Color
    ) -> AttributedString {
        let displayValues = resolvedDisplayValues(
            for: descriptor,
            scale: scale,
            unitSystem: unitSystem
        )

        return IngredientHighlighter.highlight(
            ingredient: RecipeIngredient(
                id: descriptor.id,
                sortIndex: descriptor.sortIndex,
                ingredientText: displayValues.ingredientText,
                ingredientPart: descriptor.ingredientPart,
                extraInformation: descriptor.extraInformation,
                quantity: displayValues.quantity.map {
                    IngredientQuantity(quantity: $0, quantityText: displayValues.quantityText)
                },
                unit: displayValues.unitText.map {
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
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem
    ) -> String {
        resolvedDisplayValues(for: descriptor, scale: scale, unitSystem: unitSystem).ingredientText
    }

    static func scaledQuantityText(
        for descriptor: IngredientScaleDescriptor,
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem
    ) -> String? {
        resolvedDisplayValues(for: descriptor, scale: scale, unitSystem: unitSystem).quantityText
    }

    static func scaledUnitText(
        for descriptor: IngredientScaleDescriptor,
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem
    ) -> String? {
        resolvedDisplayValues(for: descriptor, scale: scale, unitSystem: unitSystem).unitText
    }

    static func resolvedDisplayValues(
        for descriptor: IngredientScaleDescriptor,
        scale: Double,
        unitSystem: RecipeIngredientUnitSystem
    ) -> DisplayIngredientValues {
        let source = descriptor.ingredientText.trimmingCharacters(in: .whitespacesAndNewlines)
        let scaledQuantity = descriptor.quantity.map { $0 * scale }

        var finalQuantity = scaledQuantity
        var finalUnitText = descriptor.unitText?.trimmingCharacters(in: .whitespacesAndNewlines)

        if unitSystem != .original,
           let scaledQuantity,
           let unitText = descriptor.unitText,
           let canonicalUnit = canonicalUnit(for: unitText),
           let converted = convertedQuantityAndUnit(
                quantity: scaledQuantity,
                unit: canonicalUnit,
                to: unitSystem
           ) {
            finalQuantity = converted.quantity
            finalUnitText = converted.unit.displayText
        }

        let finalQuantityText = finalQuantity.map(formatScale)
        let finalIngredientText = replacingQuantityAndUnitText(
            in: source,
            originalQuantityText: descriptor.quantityText,
            replacementQuantityText: finalQuantityText,
            originalUnitText: descriptor.unitText,
            replacementUnitText: finalUnitText
        )

        return DisplayIngredientValues(
            ingredientText: finalIngredientText,
            quantity: finalQuantity,
            quantityText: finalQuantityText,
            unitText: finalUnitText
        )
    }

    static func replacingQuantityAndUnitText(
        in source: String,
        originalQuantityText: String?,
        replacementQuantityText: String?,
        originalUnitText: String?,
        replacementUnitText: String?
    ) -> String {
        var updated = source
        guard !updated.isEmpty else { return updated }

        var searchStart = updated.startIndex

        if let oldQuantity = originalQuantityText?.trimmingCharacters(in: .whitespacesAndNewlines),
           !oldQuantity.isEmpty,
           let newQuantity = replacementQuantityText,
           let qtyRange = updated.range(of: oldQuantity, options: [.caseInsensitive]) {
            let lowerBound = qtyRange.lowerBound
            updated.replaceSubrange(qtyRange, with: newQuantity)
            searchStart = updated.index(lowerBound, offsetBy: newQuantity.count, limitedBy: updated.endIndex) ?? updated.endIndex
        }

        guard let oldUnit = originalUnitText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !oldUnit.isEmpty,
              let newUnit = replacementUnitText?.trimmingCharacters(in: .whitespacesAndNewlines),
              !newUnit.isEmpty,
              oldUnit.caseInsensitiveCompare(newUnit) != .orderedSame else {
            return updated
        }

        if let nearbyUnitRange = updated.range(of: oldUnit, options: [.caseInsensitive], range: searchStart..<updated.endIndex) {
            updated.replaceSubrange(nearbyUnitRange, with: newUnit)
            return updated
        }

        if let anyUnitRange = updated.range(of: oldUnit, options: [.caseInsensitive]) {
            updated.replaceSubrange(anyUnitRange, with: newUnit)
        }

        return updated
    }

    static func canonicalUnit(for unitText: String) -> CanonicalIngredientUnit? {
        let normalized = unitText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
            .replacingOccurrences(of: ".", with: "")
            .replacingOccurrences(of: "-", with: "")
            .replacingOccurrences(of: " ", with: "")

        switch normalized {
        case "g", "gram", "grams":
            return .gram
        case "kg", "kgs", "kilogram", "kilograms", "kilo", "kilos":
            return .kilogram
        case "oz", "ounce", "ounces":
            return .ounce
        case "lb", "lbs", "pound", "pounds":
            return .pound
        case "ml", "milliliter", "milliliters", "millilitre", "millilitres":
            return .milliliter
        case "l", "lt", "liter", "liters", "litre", "litres":
            return .liter
        case "floz", "fluidounce", "fluidounces", "flounce", "flounces":
            return .fluidOunce
        case "cup", "cups", "c":
            return .cup
        case "pt", "pint", "pints":
            return .pint
        case "qt", "quart", "quarts":
            return .quart
        case "gal", "gallon", "gallons":
            return .gallon
        default:
            return nil
        }
    }

    static func convertedQuantityAndUnit(
        quantity: Double,
        unit: CanonicalIngredientUnit,
        to unitSystem: RecipeIngredientUnitSystem
    ) -> (quantity: Double, unit: CanonicalIngredientUnit)? {
        guard unitSystem != .original else {
            return (quantity, unit)
        }

        guard unit.system != unitSystem else {
            return (quantity, unit)
        }

        switch unit.family {
        case .mass:
            let grams = toGrams(quantity: quantity, unit: unit)
            if unitSystem == .metric {
                if grams >= 1000 {
                    return (grams / 1000, .kilogram)
                }
                return (grams, .gram)
            } else {
                if grams >= 453.59237 {
                    return (grams / 453.59237, .pound)
                }
                return (grams / 28.349523125, .ounce)
            }

        case .volume:
            let milliliters = toMilliliters(quantity: quantity, unit: unit)
            if unitSystem == .metric {
                if milliliters >= 1000 {
                    return (milliliters / 1000, .liter)
                }
                return (milliliters, .milliliter)
            } else {
                if milliliters >= 3_785.411784 {
                    return (milliliters / 3_785.411784, .gallon)
                }
                if milliliters >= 946.352946 {
                    return (milliliters / 946.352946, .quart)
                }
                if milliliters >= 473.176473 {
                    return (milliliters / 473.176473, .pint)
                }
                if milliliters >= 236.5882365 {
                    return (milliliters / 236.5882365, .cup)
                }
                return (milliliters / 29.5735295625, .fluidOunce)
            }
        }
    }

    static func toGrams(quantity: Double, unit: CanonicalIngredientUnit) -> Double {
        switch unit {
        case .gram:
            return quantity
        case .kilogram:
            return quantity * 1000
        case .ounce:
            return quantity * 28.349523125
        case .pound:
            return quantity * 453.59237
        case .milliliter, .liter, .fluidOunce, .cup, .pint, .quart, .gallon:
            return quantity
        }
    }

    static func toMilliliters(quantity: Double, unit: CanonicalIngredientUnit) -> Double {
        switch unit {
        case .milliliter:
            return quantity
        case .liter:
            return quantity * 1000
        case .fluidOunce:
            return quantity * 29.5735295625
        case .cup:
            return quantity * 236.5882365
        case .pint:
            return quantity * 473.176473
        case .quart:
            return quantity * 946.352946
        case .gallon:
            return quantity * 3_785.411784
        case .gram, .kilogram, .ounce, .pound:
            return quantity
        }
    }
}
