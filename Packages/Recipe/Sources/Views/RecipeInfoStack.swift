//
//  RecipeInfoStack.swift
//  Recipe
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API

public struct RecipeInfoStack: View {
    
    private let recipe: Recipe
    
    public init (_ recipe: Recipe) {
        self.recipe = recipe
    }
    
    public var body: some View {
        HStack {
            if let totalMins = recipe.totalMins {
                RecipeInfoCard(recipe, title: "\(totalMins.formatted()) mins", image: "clock.circle.fill")
            }
            
            if let ratings = recipe.ratings.overallRating {
                RecipeInfoCard(recipe, title: "\(ratings.formatted())", image: "star.fill")
            }
            
            if let serves = recipe.serves, serves.isNumber {
                RecipeInfoCard(recipe, title: "\(serves)", image: "person.fill")
            }
            Spacer()
        }
    }
}
