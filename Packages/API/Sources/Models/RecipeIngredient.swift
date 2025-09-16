//
//  RecipeIngredient.swift
//  API
//
//  Created by Tom Knighton on 16/09/2025.
//

public struct RecipeIngredient: Codable, Hashable, Equatable, Identifiable {
    public static func == (lhs: RecipeIngredient, rhs: RecipeIngredient) -> Bool {
        lhs.quantity == rhs.quantity && lhs.fullIngredient == rhs.fullIngredient
    }
    
    public func hash(into hasher: inout Hasher) {
        hasher.combine(fullIngredient)
        hasher.combine(quantity)
        hasher.combine(unitText)
    }
    
    public var id: String { fullIngredient }
    
    public let quantity: Double?
    public let quantityText: String?
    public let minQuantity: Double?
    public let maxQuantity: Double?
    public let unit: String?
    public let unitText: String?
    public let ingredient: String?
    public let extra: String?
    public let fullIngredient: String
    public let alternativeQuantities: [RecipeIngredientAlternativeQuantity]
    
    public init(quantity: Double?, quantityText: String?, minQuantity: Double?, maxQuantity: Double?, unit: String?, unitText: String?, ingredient: String?, extra: String?, fullIngredient: String, alternativeQuantities: [RecipeIngredientAlternativeQuantity]) {
        self.quantity = quantity
        self.quantityText = quantityText
        self.minQuantity = minQuantity
        self.maxQuantity = maxQuantity
        self.unit = unit
        self.unitText = unitText
        self.ingredient = ingredient
        self.extra = extra
        self.fullIngredient = fullIngredient
        self.alternativeQuantities = alternativeQuantities
    }
}

public struct RecipeIngredientAlternativeQuantity: Codable {
    
    public let quantity: Double
    public let unit: String
    public let unitText: String
    public let minQuantity: Double?
    public let maxQuantity: Double?
    
    public init(quantity: Double, unit: String, unitText: String, minQuantity: Double?, maxQuantity: Double?) {
        self.quantity = quantity
        self.unit = unit
        self.unitText = unitText
        self.minQuantity = minQuantity
        self.maxQuantity = maxQuantity
    }
}
