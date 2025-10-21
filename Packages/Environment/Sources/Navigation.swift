//
//  Na.swift
//  Environment
//
//  Created by Tom Knighton on 19/09/2025.
//

import AppRouter
import Foundation
import API
import SwiftUI

public enum AppTab: String, Codable, TabType, CaseIterable {
    case recipes
    case settings
    
    public var id: String { rawValue }
    
    public var icon: String {
        switch self {
        case .recipes: return "square.stack"
        case .settings: return "gearshape.fill"
        }
    }
    
    public var title: String {
        switch self {
        case .recipes: return "Recipes"
        case .settings: return "Settings"
        }
    }
}

public enum AppDestination: DestinationType {
    case recipes
    case recipe(recipe: Recipe)
    
    public static func from(path: String, fullPath: [String], parameters: [String : String]) -> AppDestination? {
        return nil
    }
}

public enum AppSheet: SheetType {
    
    public var id: Int { hashValue }
    
    case timersView
    case householdSettings
}

public typealias AppRouter = Router<AppTab, AppDestination, AppSheet>

@Observable
public class ZoomManager {
    public let zoomNamespace: Namespace.ID
    
    public init(_ zoomNamespace: Namespace.ID) {
        self.zoomNamespace = zoomNamespace
    }
}
