//
//  RecipeDiscoveryImportContext.swift
//  RecipesList
//

import API
import Environment
import Foundation

struct RecipeDiscoveryImportContext: Sendable {
    let item: DiscoveryFeedItem
    let identity: DiscoveryIdentity
}
