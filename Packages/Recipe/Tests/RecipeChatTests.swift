import Dependencies
import Foundation
import Models
import Persistence
import Testing
@testable import Recipe

@MainActor
struct RecipeChatTests {

#if targetEnvironment(simulator)
    @Test func unsignedSimulatorDoesNotAdvertiseCloudAccess() {
        #expect(!RecipeIntelligence(cloudEnabled: true).availabilityDescription.contains("Private Cloud Compute"))
    }
#endif

    @Test func contextKeepsStepsInTheirSectionOrderAndIncludesLaterSteps() throws {
        let model = try makeModel(sections: [
            section(order: 1, steps: [step(order: 0, text: "Finish the sauce")]),
            section(order: 0, steps: (0..<10).reversed().map { step(order: $0, text: "Prepare item \($0)") })
        ])
        let context = model.compactRecipeContext()
        #expect(context.contains("1. Prepare item 0"))
        #expect(context.contains("10. Prepare item 9"))
        #expect(context.contains("11. Finish the sauce"))
        #expect(context.contains("Complete ingredients and steps."))
    }

    @Test func localContextDisclosesOmissionsWhileCloudKeepsLongerInstructions() throws {
        let instructions = String(repeating: "Stir gently. ", count: 600)
        let model = try makeModel(sections: [section(order: 0, steps: [step(order: 0, text: instructions)])])
        #expect(model.compactRecipeContext().contains("Incomplete; some recipe text was omitted."))
        #expect(!model.compactRecipeContext().contains(instructions))
        #expect(model.compactRecipeContext(useCloud: true).contains(instructions))
    }

    @Test func clearingChatResetsPendingStateAndHistory() throws {
        let model = try makeModel(sections: [])
        model.recipeChatResponding = true
        model.recipeChatError = "Failed"
        model.recipeChatRoute = "Private Cloud Compute"
        model.recipeChatMessages = [.init(role: .user, content: "Can I make this ahead?")]
        model.clearRecipeChat()
        #expect(!model.recipeChatResponding)
        #expect(model.recipeChatMessages.isEmpty)
        #expect(model.recipeChatError == nil)
        #expect(model.recipeChatRoute == nil)
    }

    private func section(order: Int, steps: [RecipeStep]) -> RecipeStepSection {
        .init(id: UUID(), sortIndex: order, title: "Section", steps: steps)
    }

    private func step(order: Int, text: String) -> RecipeStep {
        .init(id: UUID(), sortIndex: order, instructionText: text, timings: [], temperatures: [], linkedIngredients: [])
    }

    private func makeModel(sections: [RecipeStepSection]) throws -> RecipeViewModel {
        let database = try AppDatabaseFactory.makeAppDatabase()
        let recipe = Models.Recipe(
            id: UUID(), title: "Test recipe", description: nil, summarisedTip: nil,
            author: nil, sourceUrl: "https://example.com", image: .init(imageThumbnailData: nil, imageUrl: nil),
            timing: .init(totalTime: nil, prepTime: nil, cookTime: nil), serves: nil,
            ratingInfo: nil, dateAdded: .now, dateModified: .now, ingredientSections: [],
            stepSections: sections, dominantColorHex: nil, homeId: nil
        )
        return withDependencies {
            $0.defaultDatabase = database
        } operation: {
            RecipeViewModel(recipe: recipe)
        }
    }
}
