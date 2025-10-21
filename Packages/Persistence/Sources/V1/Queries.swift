//
//  Queries.swift
//  Persistence
//
//  Created by Tom Knighton on 20/10/2025.
//

import Foundation
import SQLiteData

@Selection
public struct FullDBRecipe: Identifiable {
    public let recipe: DBRecipe
    
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
    
    public var id: UUID { recipe.id }
}

public extension DBRecipe {
    
    static var full: Select<FullDBRecipe, DBRecipe, (DBRecipeIngredientGroup?, DBRecipeIngredient?, DBRecipeStepGroup?, DBRecipeStep?, DBRecipeStepTiming?, DBRecipeStepTemperature?)> {
        let query: Select<FullDBRecipe, DBRecipe, (DBRecipeIngredientGroup?, DBRecipeIngredient?, DBRecipeStepGroup?, DBRecipeStep?, DBRecipeStepTiming?, DBRecipeStepTemperature?)> = DBRecipe
            .group(by: \.id)
            .leftJoin(DBRecipeIngredientGroup.all) { $0.id.eq($1.recipeId) }
            .leftJoin(DBRecipeIngredient.all) { $1.id.eq($2.ingredientGroupId) }
            .leftJoin(DBRecipeStepGroup.all) { $0.id.eq($3.recipeId) }
            .leftJoin(DBRecipeStep.all) { $3.id.eq($4.groupId) }
            .leftJoin(DBRecipeStepTiming.all) { $4.id.eq($5.recipeStepId) }
            .leftJoin(DBRecipeStepTemperature.all) { $4.id.eq($6.recipeStepId) }
            .select {
                FullDBRecipe.Columns(
                    recipe: $0,
                    ingredientGroups: $1.jsonGroupArray(distinct: true),
                    ingredients: $2.jsonGroupArray(distinct: true),
                    stepGroups: $3.jsonGroupArray(distinct: true),
                    steps: $4.jsonGroupArray(distinct: true),
                    timings: $5.jsonGroupArray(distinct: true),
                    temperatures: $6.jsonGroupArray(distinct: true),
                )
            }
        
        return query
    }
}
