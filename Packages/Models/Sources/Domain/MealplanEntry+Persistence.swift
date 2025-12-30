//
//  MealplanEntry+Persistence.swift
//  Models
//
//  Created by Tom Knighton on 17/11/2025.
//

import Persistence

public extension FullDBMealplanEntry {
    
    func toDomainModel() -> MealplanEntry {
        
        var recipe: Recipe? = nil
        
        if let dbRecipe = self.recipe {
            let image = RecipeImage(imageThumbnailData: self.image?.imageData, imageUrl: self.image?.imageSourceUrl)

            recipe = Recipe(id: dbRecipe.id, title: dbRecipe.title, description: dbRecipe.description, author: dbRecipe.author, sourceUrl: dbRecipe.sourceUrl, image: image, timing: .init(totalTime: dbRecipe.totalMins, prepTime: dbRecipe.minutesToPrepare, cookTime: dbRecipe.minutesToCook), serves: dbRecipe.serves, ratingInfo: nil, dateAdded: dbRecipe.dateAdded, dateModified: dbRecipe.dateModified, ingredientSections: [], stepSections: [], dominantColorHex: dbRecipe.dominantColorHex, homeId: dbRecipe.homeId)
        }
        
        return MealplanEntry(id: self.id, date: self.mealplanEntry.date, index: self.mealplanEntry.index, note: self.mealplanEntry.noteText, recipe: recipe, homeId: self.mealplanEntry.homeId)
    }
}
