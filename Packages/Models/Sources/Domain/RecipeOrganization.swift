//
//  RecipeOrganization.swift
//  Models
//
//  Created by Tom Knighton on 19/05/2026.
//

import Foundation
import Persistence

public struct RecipeFolder: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var homeId: UUID?
    public var parentFolderId: UUID?
    public var name: String
    public var symbolName: String
    public var colorHex: String
    public var sortIndex: Int

    public init(id: UUID, homeId: UUID?, parentFolderId: UUID? = nil, name: String, symbolName: String, colorHex: String, sortIndex: Int) {
        self.id = id
        self.homeId = homeId
        self.parentFolderId = parentFolderId
        self.name = name
        self.symbolName = symbolName
        self.colorHex = colorHex
        self.sortIndex = sortIndex
    }
}

public struct RecipeTag: Identifiable, Hashable, Sendable, Codable {
    public let id: UUID
    public var homeId: UUID?
    public var name: String
    public var colorHex: String

    public init(id: UUID, homeId: UUID?, name: String, colorHex: String) {
        self.id = id
        self.homeId = homeId
        self.name = name
        self.colorHex = colorHex
    }
}

public extension DBRecipeFolder {
    func toDomainModel(parentFolderId: UUID? = nil) -> RecipeFolder {
        RecipeFolder(
            id: id,
            homeId: homeId,
            parentFolderId: parentFolderId,
            name: name,
            symbolName: symbolName,
            colorHex: colorHex,
            sortIndex: sortIndex
        )
    }
}

public extension DBRecipeTag {
    func toDomainModel() -> RecipeTag {
        RecipeTag(
            id: id,
            homeId: homeId,
            name: name,
            colorHex: colorHex
        )
    }
}
