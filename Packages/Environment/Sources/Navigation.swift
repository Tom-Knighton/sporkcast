//
//  Na.swift
//  Environment
//
//  Created by Tom Knighton on 19/09/2025.
//

import AppRouter
import Foundation
import SwiftUI

public enum AppTab: String, TabType, CaseIterable {
    case recipes
    case testRecipe
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .recipes: return "square.stack"
        case .testRecipe: return "hammer"
        }
    }
    
    public var title: String {
        switch self {
        case .recipes: return "Recipes"
        case .testRecipe: return "Test Recipe"
        }
    }
}

public enum AppDestination: DestinationType {
    case recipes
    case recipe(id: UUID)
    
    public static func from(path: String, fullPath: [String], parameters: [String : String]) -> AppDestination? {
        return nil
    }
}

public enum AppSheet: SheetType {
    
    public var id: Int { hashValue }
    
    case timersView
}

public typealias AppRouter = Router<AppTab, AppDestination, AppSheet>

@Observable
public class ZoomManager {
    public let zoomNamespace: Namespace.ID
    
    public init(_ zoomNamespace: Namespace.ID) {
        self.zoomNamespace = zoomNamespace
    }
}
