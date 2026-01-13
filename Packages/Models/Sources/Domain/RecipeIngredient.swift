//
//  RecipeIngredient.swift
//  API
//
//  Created by Tom Knighton on 21/10/2025.
//

import Foundation

public struct RecipeIngredientGroup: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    
    /// The title of the ingredients section i.e. 'For the sauce' etc.
    public let title: String

    /// Where the group is ordered in the list of groups
    public let sortIndex: Int
    
    public var ingredients: [RecipeIngredient]
    
    public init(id: UUID, title: String, sortIndex: Int, ingredients: [RecipeIngredient]) {
        self.id = id
        self.title = title
        self.sortIndex = sortIndex
        self.ingredients = ingredients
    }
}

public struct RecipeIngredient: Identifiable, Hashable, Equatable, Sendable, Codable {
    public let id: UUID
    
    /// Where the ingredient is ordered within it's group
    public let sortIndex: Int
    
    /// The full raw ingredient string
    public var ingredientText: String
    
    /// A parsed piece of text attempting to represent the actual ingredient i.e. 'brocolli' in '2tsp brocolli'
    public var ingredientPart: String?
    
    /// Any extra information that was able to be parsed i.e. 'chopped', 'diced'
    public var extraInformation: String?

    
    /// If parsed, structured details on the quantity of the ingredient
    public var quantity: IngredientQuantity?
    
    /// If parsed, structured details on the unit of the ingredient
    public var unit: IngredientUnit?
    
    /// If present, the emoji that should represent this ingredient
    public var emoji: String?
    
    /// Whether the user owns this ingredient
    public let owned: Bool?
    
    public init(id: UUID, sortIndex: Int, ingredientText: String, ingredientPart: String?, extraInformation: String?, quantity: IngredientQuantity?, unit: IngredientUnit?, emoji: String?, owned: Bool?) {
        self.id = id
        self.sortIndex = sortIndex
        self.ingredientText = ingredientText
        self.ingredientPart = ingredientPart
        self.extraInformation = extraInformation
        self.quantity = quantity
        self.unit = unit
        self.emoji = emoji
        self.owned = owned
    }
}

public struct IngredientQuantity: Hashable, Sendable, Codable {
    
    /// If parsed, the actual integer quantity of the ingredient i.e. '2' or '2.5
    public let quantity: Double?
    
    /// If parsed, the text in the ingredient's original text the quantity was extracted from i.e. '2' 'two' or '2 1/12' etc.
    public let quantityText: String?
    
    public init(quantity: Double?, quantityText: String?) {
        self.quantity = quantity
        self.quantityText = quantityText
    }
}

public struct IngredientUnit: Hashable, Sendable, Codable {
    
    /// If parsed, the actual unit of the ingredient i.e. 'cup' 'teaspoon' etc.
    public let unit: String?
    
    /// If parsed, the text in the original ingredient's original text the unit was extracted from i.e. 'cup', 'teaspoon', 'tsp' etc.
    public let unitText: String?
    
    public init(unit: String?, unitText: String?) {
        self.unit = unit
        self.unitText = unitText
    }
}

