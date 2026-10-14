import Foundation
import Models
import Testing
@testable import Environment

@Suite @MainActor
struct RecipeLibraryNavigationTests {
    @Test func presentationDefaultsToGridAndPersistsChoice() throws {
        let suite = "RecipeLibraryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }

        let navigation = RecipeLibraryNavigation(defaults: defaults)
        #expect(navigation.presentation == .grid)
        navigation.presentation = .listAndDetail
        #expect(RecipeLibraryNavigation(defaults: defaults).presentation == .listAndDetail)
    }

    @Test func splitRoutingPreservesFolderPathAndRecipeContext() throws {
        let suite = "RecipeLibraryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let navigation = RecipeLibraryNavigation(defaults: defaults)
        navigation.presentation = .listAndDetail
        let folderID = UUID()
        let recipe = makeRecipe()
        let suffix = UUID().uuidString
        var path: [AppDestination] = [.recipes(folderID: folderID), .recipe(recipe: recipe, zoomSuffix: suffix)]

        #expect(navigation.consumeRecipeDestination(from: &path))
        #expect(path == [.recipes(folderID: folderID)])
        #expect(navigation.selectedRecipe?.id == recipe.id)
        #expect(navigation.zoomSuffix == suffix)
        #expect(!navigation.consumeRecipeDestination(from: &path))
    }

    @Test func gridLeavesDeepLinksInTheNavigationStack() throws {
        let suite = "RecipeLibraryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let navigation = RecipeLibraryNavigation(defaults: defaults)
        let recipe = makeRecipe()
        var path: [AppDestination] = [.recipe(recipe: recipe)]

        #expect(!navigation.consumeRecipeDestination(from: &path))
        #expect(path == [.recipe(recipe: recipe)])
        #expect(navigation.selectedRecipe == nil)
    }

    @Test func reselectingAfterBackRequestsDetailAgain() throws {
        let suite = "RecipeLibraryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let navigation = RecipeLibraryNavigation(defaults: defaults)
        let recipe = makeRecipe()
        navigation.select(recipe)
        let revision = navigation.selectionRevision
        navigation.select(recipe)
        #expect(navigation.selectionRevision > revision)
        navigation.clearSelection()
        #expect(navigation.selectedRecipe == nil)
        #expect(navigation.zoomSuffix == nil)
    }

    @Test func narrowLayoutKeepsPreferenceButUsesOrdinaryNavigation() throws {
        let suite = "RecipeLibraryTests.\(UUID())"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let navigation = RecipeLibraryNavigation(defaults: defaults)
        navigation.presentation = .listAndDetail
        navigation.isSplitViewAvailable = false
        let recipe = makeRecipe()
        var path: [AppDestination] = [.recipe(recipe: recipe)]

        #expect(navigation.activePresentation == .grid)
        #expect(!navigation.consumeRecipeDestination(from: &path))
        #expect(navigation.presentation == .listAndDetail)
        navigation.isSplitViewAvailable = true
        #expect(navigation.consumeRecipeDestination(from: &path))
        #expect(navigation.selectedRecipe?.id == recipe.id)
    }

    private func makeRecipe() -> Recipe {
        Recipe(id: UUID(), title: "Pasta", description: nil, summarisedTip: nil, author: nil,
               sourceUrl: "https://example.com/pasta", image: .init(imageThumbnailData: nil, imageUrl: nil),
               timing: .init(totalTime: 25, prepTime: 10, cookTime: 15), serves: "2", ratingInfo: nil,
               dateAdded: .now, dateModified: .now, ingredientSections: [], stepSections: [],
               dominantColorHex: nil, homeId: nil)
    }
}
