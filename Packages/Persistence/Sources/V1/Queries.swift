//
//  Queries.swift
//  Persistence
//
//  Created by Tom Knighton on 20/10/2025.
//

import Foundation
import SQLiteData

@Selection
public struct FullDBRecipe: Sendable, Identifiable, Equatable {
    
    public let recipe: DBRecipe
    
    public let imageData: DBRecipeImage?
    
    @Column(as: [DBRecipeIngredientGroup].JSONRepresentation.self)
    public let ingredientGroups: [DBRecipeIngredientGroup]
    
    @Column(as: [DBRecipeIngredient].JSONRepresentation.self)
    public let ingredients: [DBRecipeIngredient]
    
    @Column(as: [DBRecipeStepGroup].JSONRepresentation.self)
    public let stepGroups: [DBRecipeStepGroup]
    
    @Column(as: [DBRecipeStep].JSONRepresentation.self)
    public let steps: [DBRecipeStep]
    
    @Column(as: [DBRecipeStepTiming].JSONRepresentation.self)
    public let timings: [DBRecipeStepTiming]
    
    @Column(as: [DBRecipeStepTemperature].JSONRepresentation.self)
    public let temperatures: [DBRecipeStepTemperature]
    
    @Column(as: [DBRecipeRating].JSONRepresentation.self)
    public let ratings: [DBRecipeRating]
    
    @Column(as: [DBRecipeStepLinkedIngredient].JSONRepresentation.self)
    public let stepLinkedIngredients: [DBRecipeStepLinkedIngredient]
    
    public var id: UUID { recipe.id }
}

@Selection
public struct FullDBMealplanEntry: Sendable, Identifiable, Equatable {
    
    public let mealplanEntry: DBMealplanEntry
    public let recipe: DBRecipe?
    public let image: DBRecipeImage?
    
    public var id: UUID { mealplanEntry.id }
}

@Selection
public struct FullDBShoppingList: Sendable, Identifiable, Equatable {
    
    public let shoppingList: DBShoppingList
    
    @Column(as: [DBShoppingListItem].JSONRepresentation.self)
    public let items: [DBShoppingListItem]
    
    public var id: UUID { shoppingList.id }
    
    public init(shoppingList: DBShoppingList, items: [DBShoppingListItem]) {
        self.shoppingList = shoppingList
        self.items = items
    }
}

public extension DBRecipe {
    
    typealias FullSelect = Select<FullDBRecipe, DBRecipe, (DBRecipeIngredientGroup?, DBRecipeIngredient?, DBRecipeStepGroup?, DBRecipeStep?, DBRecipeStepTiming?, DBRecipeStepTemperature?, DBRecipeImage?, DBRecipeRating?, DBRecipeStepLinkedIngredient?)>
    
    static var full: FullSelect {
        
        let base = DBRecipe
            .group(by: \.id)
            .order(by: \.dateModified)
        
        let withIngGroups = base.leftJoin(DBRecipeIngredientGroup.all) {
            $0.id.eq($1.recipeId)
        }
        
        let withIngs = withIngGroups.leftJoin(DBRecipeIngredient.all) {
            $1.id.eq($2.ingredientGroupId)
        }
        
        let withStepGroups = withIngs.leftJoin(DBRecipeStepGroup.all) {
            $0.id.eq($3.recipeId)
        }
        
        let withSteps = withStepGroups.leftJoin(DBRecipeStep.all) {
            $3.id.eq($4.groupId)
        }
        
        let withStepTimings = withSteps.leftJoin(DBRecipeStepTiming.all) {
            $4.id.eq($5.recipeStepId)
        }
        
        let withStepTemps = withStepTimings
            .leftJoin(DBRecipeStepTemperature.all) {
                $4.id.eq($6.recipeStepId)
            }
        
        let withImage = withStepTemps
            .leftJoin(DBRecipeImage.all) {
                $0.id.eq($7.recipeId)
            }
        
        let withRatings = withImage
            .leftJoin(DBRecipeRating.all) {
                $0.id.eq($8.recipeId)
            }
        
        let withStepIngredients = withRatings
            .leftJoin(DBRecipeStepLinkedIngredient.all) {
                $4.id.eq($9.recipeStepId)
            }
    
        let query = withStepIngredients
            .select {
                let igs = $1.jsonGroupArray(distinct: true)
                let ings = $2.jsonGroupArray(distinct: true)
                let stepLinkedIngs = $9.jsonGroupArray(distinct: true)
                return FullDBRecipe.Columns(
                    recipe: $0,
                    imageData: $7,
                    ingredientGroups: igs,
                    ingredients: ings,
                    stepGroups: $3.jsonGroupArray(distinct: true),
                    steps: $4.jsonGroupArray(distinct: true),
                    timings: $5.jsonGroupArray(distinct: true),
                    temperatures: $6.jsonGroupArray(distinct: true),
                    ratings: $8.jsonGroupArray(distinct: true),
                    stepLinkedIngredients: stepLinkedIngs
                )
            }
        
        
       return query
    }
}

public extension DBMealplanEntry {
    
    typealias FullSelect = Select<FullDBMealplanEntry, DBMealplanEntry, (DBRecipe?, DBRecipeImage?)>
    
    static func full(startDate: Date, endDate: Date) -> FullSelect {
        let base = DBMealplanEntry
            .group(by: \.id)
            .order(by: \.date)
            .where { $0.date >= #bind(startDate) && $0.date <= #bind(endDate)}
        
        let withRecipe = base.leftJoin(DBRecipe.all) {
            $0.recipeId.eq($1.id)
        }
        
        let withImage = withRecipe.leftJoin(DBRecipeImage.all) {
            $0.recipeId.eq($2.recipeId)
        }
                
        let query = withImage
            .select {
                return FullDBMealplanEntry.Columns(mealplanEntry: $0, recipe: $1, image: $2)
            } 
        
        return query
    }
}

public extension DBShoppingList {
    
    typealias FullSelect = Select<FullDBShoppingList, DBShoppingList, (DBShoppingListItem?)>
    
    static var full: FullSelect {
        let base = DBShoppingList
            .group(by: \.id)

        let withItems = base.leftJoin(DBShoppingListItem.all) {
            $0.id.eq($1.listId)
        }
        
        let query = withItems
            .select {
                return FullDBShoppingList.Columns(shoppingList: $0, items: $1.jsonGroupArray(distinct: true))
            }
        
        return query
    }
}
