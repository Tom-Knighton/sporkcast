internal import AppRouter
import Models
import Design
import Environment
import Recipe
import RecipesList
import SwiftUI

struct RecipeLibraryNavigationView<Collection: View>: View {
    @Environment(AppRouter.self) private var router
    @Environment(\.homeServices) private var homes
    @State private var library = RecipeLibraryNavigation()
    @State private var browsing = RecipeBrowsingSessions()
    @State private var columnVisibility = NavigationSplitViewVisibility.all
    @State private var compactColumn = NavigationSplitViewColumn.sidebar

    var startsWithFolders = false
    let collection: () -> Collection

    var body: some View {
        @Bindable var router = router

        Group {
            if library.activePresentation == .listAndDetail {
                NavigationSplitView(columnVisibility: $columnVisibility, preferredCompactColumn: $compactColumn) {
                    NavigationStack(path: $router[.recipes]) {
                        collection()
                    }
                    .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
                } detail: {
                    NavigationStack {
                        if let recipe = library.selectedRecipe {
                            RecipeDestinationView(recipe: recipe, zoomSuffix: library.zoomSuffix)
                                .id(recipe.id)
                        } else {
                            ContentUnavailableView("Select a Recipe", systemImage: "book.closed", description: Text("Choose a recipe from your collection to see ingredients and cooking steps."))
                        }
                    }
                }
                .navigationSplitViewStyle(.balanced)
            } else {
                NavigationStack(path: $router[.recipes]) {
                    collection()
                }
            }
        }
        .environment(\.recipeLibraryNavigation, library)
        .environment(\.recipeBrowsingSessions, browsing)
        .environment(\.recipeCookingColumnsAllowed, library.activePresentation != .listAndDetail || columnVisibility == .detailOnly)
        .onGeometryChange(for: Bool.self) { geometry in
            // Leave enough room for the collection and a readable recipe pane.
            geometry.size.width >= 760
        } action: { isAvailable in
            if !isAvailable, library.isSplitViewAvailable,
               library.presentation == .listAndDetail,
               let recipe = library.selectedRecipe {
                var path = router[.recipes]
                path.append(.recipe(recipe: recipe, zoomSuffix: library.zoomSuffix))
                router[.recipes] = path
            }
            library.isSplitViewAvailable = isAvailable
            routeRecipeToDetail()
        }
        .onChange(of: library.presentation, initial: true) { _, _ in
            routeRecipeToDetail()
            columnVisibility = .all
            compactColumn = .sidebar
        }
        .onChange(of: router[.recipes]) { _, _ in
            routeRecipeToDetail()
        }
        .onChange(of: library.selectionRevision) { _, _ in
            compactColumn = library.selectedRecipe == nil ? .sidebar : .detail
            columnVisibility = .all
        }
        .onChange(of: homes.home?.id) { _, _ in
            library.clearSelection()
            browsing.clear()
        }
    }

    private func routeRecipeToDetail() {
        var path = router[.recipes]
        if library.consumeRecipeDestination(from: &path) {
            if startsWithFolders && path.isEmpty {
                path = [.recipes()]
            }
            router[.recipes] = path
        }
    }
}
