import AppIntents
import Models
import Recipe
import SwiftUI

struct RecipeDestinationView: View {
    let recipe: Models.Recipe
    var zoomSuffix: String?
    var namespace: Namespace.ID?

    var body: some View {
        let page = RecipePage(recipe, mealplanEntryId: zoomSuffix.flatMap(UUID.init(uuidString:)))

        Group {
            if let namespace {
                page.navigationTransition(.zoom(
                    sourceID: "zoom-\(recipe.id.uuidString)\(zoomSuffix.map { "-\($0)" } ?? "")",
                    in: namespace
                ))
            } else {
                page
            }
        }
        .modifier(RecipeActivityModifier(recipe: recipe))
    }
}
