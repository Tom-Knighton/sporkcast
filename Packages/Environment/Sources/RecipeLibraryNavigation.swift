import Models
import Observation
import SwiftUI

@Observable
@MainActor
public final class RecipeLibraryNavigation {
    private static let preferenceKey = "recipes.library.presentation.v1"
    @ObservationIgnored private let defaults: UserDefaults

    public var presentation: RecipeLibraryPresentation {
        didSet { defaults.set(presentation.rawValue, forKey: Self.preferenceKey) }
    }
    public private(set) var selectedRecipe: Recipe?
    public private(set) var zoomSuffix: String?
    public private(set) var selectionRevision = 0
    public var isSplitViewAvailable = true

    public var activePresentation: RecipeLibraryPresentation {
        isSplitViewAvailable ? presentation : .grid
    }

    public init(defaults: UserDefaults = .appGroup) {
        self.defaults = defaults
        presentation = defaults.string(forKey: Self.preferenceKey)
            .flatMap(RecipeLibraryPresentation.init(rawValue:)) ?? .grid
    }

    public func select(_ recipe: Recipe, zoomSuffix: String? = nil) {
        selectedRecipe = recipe
        self.zoomSuffix = zoomSuffix
        selectionRevision += 1
    }

    public func clearSelection() {
        selectedRecipe = nil
        zoomSuffix = nil
        selectionRevision += 1
    }

    /// Keep folder navigation in the collection stack while recipes open in the detail column.
    public func consumeRecipeDestination(from path: inout [AppDestination]) -> Bool {
        guard activePresentation == .listAndDetail,
              case let .recipe(recipe, suffix) = path.last else { return false }
        path.removeLast()
        select(recipe, zoomSuffix: suffix)
        return true
    }
}

public extension EnvironmentValues {
    @Entry var recipeLibraryNavigation: RecipeLibraryNavigation? = nil
}
