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
    
    public var id: UUID { recipe.id }
}

public extension DBRecipe {
    
    typealias FullSelect = Select<FullDBRecipe, DBRecipe, (DBRecipeIngredientGroup?, DBRecipeIngredient?, DBRecipeStepGroup?, DBRecipeStep?, DBRecipeStepTiming?, DBRecipeStepTemperature?, DBRecipeImage?)>
    
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
    
        let query = withImage
            .select {
                let igs = $1.jsonGroupArray(distinct: true)
                let ings = $2.jsonGroupArray(distinct: true)
                return FullDBRecipe.Columns(
                    recipe: $0,
                    imageData: $7,
                    ingredientGroups: igs,
                    ingredients: ings,
                    stepGroups: $3.jsonGroupArray(distinct: true),
                    steps: $4.jsonGroupArray(distinct: true),
                    timings: $5.jsonGroupArray(distinct: true),
                    temperatures: $6.jsonGroupArray(distinct: true),
                )
            }
        
        
       return query
    }
}

