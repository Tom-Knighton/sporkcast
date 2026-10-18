import Environment
import AppIntents
import Models
import SwiftUI

struct RecipeActivityModifier: ViewModifier {
    let recipe: Models.Recipe

    func body(content: Content) -> some View {
        if #available(iOS 27.0, *) {
            content
                .appEntityIdentifier(EntityIdentifier(for: RecipeEntity.self, identifier: recipe.id))
                .userActivity("online.tomk.sporkcast.view-recipe", element: recipe.id) { recipeID, activity in
                    activity.title = recipe.title
                    activity.targetContentIdentifier = "\(AppConfiguration.urlScheme)://recipe/\(recipeID.uuidString)"
                    activity.appEntityIdentifier = EntityIdentifier(for: RecipeEntity.self, identifier: recipeID)
                    activity.isEligibleForSearch = true
                    activity.isEligibleForPrediction = true
                }
        } else {
            content
        }
    }
}
