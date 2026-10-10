import Foundation

public enum RecipeLibraryPresentation: String, CaseIterable, Identifiable {
    case grid
    case listAndDetail

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .grid: "Grid"
        case .listAndDetail: "List & Detail"
        }
    }

    public var symbol: String {
        switch self {
        case .grid: "square.grid.2x2"
        case .listAndDetail: "rectangle.split.2x1"
        }
    }
}
