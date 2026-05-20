//
//  RecipeOrganizationRepository.swift
//  Environment
//
//  Created by Codex on 19/05/2026.
//

import Dependencies
import Foundation
import Models
import Observation
import Persistence
import SQLiteData

public struct RecipeFolderSummary: Identifiable, Hashable, Sendable {
    public let folder: RecipeFolder
    public let recipeCount: Int
    public let descendantCount: Int

    public var id: UUID { folder.id }

    public init(folder: RecipeFolder, recipeCount: Int, descendantCount: Int = 0) {
        self.folder = folder
        self.recipeCount = recipeCount
        self.descendantCount = descendantCount
    }
}

public struct RecipeTagSummary: Identifiable, Hashable, Sendable {
    public let tag: RecipeTag
    public let recipeCount: Int

    public var id: UUID { tag.id }

    public init(tag: RecipeTag, recipeCount: Int) {
        self.tag = tag
        self.recipeCount = recipeCount
    }
}

@Observable
@MainActor
public final class RecipeOrganizationRepository {

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    @ObservationIgnored
    @FetchAll(DBRecipeFolder.all) private var dbFolders: [DBRecipeFolder]

    @ObservationIgnored
    @FetchAll(DBRecipeFolderHierarchy.all) private var dbFolderHierarchy: [DBRecipeFolderHierarchy]

    @ObservationIgnored
    @FetchAll(DBRecipeTag.all) private var dbTags: [DBRecipeTag]

    @ObservationIgnored
    @FetchAll(DBRecipeFolderAssignment.all) private var dbFolderAssignments: [DBRecipeFolderAssignment]

    @ObservationIgnored
    @FetchAll(DBRecipeTagAssignment.all) private var dbTagAssignments: [DBRecipeTagAssignment]

    public var folders: [RecipeFolder] {
        let parentIDsByChildID = Dictionary(uniqueKeysWithValues: dbFolderHierarchy.map { ($0.childFolderId, $0.parentFolderId) })
        return dbFolders
            .map { $0.toDomainModel(parentFolderId: parentIDsByChildID[$0.id]) }
            .sorted {
                if $0.sortIndex == $1.sortIndex {
                    return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
                }
                return $0.sortIndex < $1.sortIndex
            }
    }

    public var tags: [RecipeTag] {
        dbTags
            .map { $0.toDomainModel() }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    public init() {}

    public func folderSummaries(homeId: UUID?) -> [RecipeFolderSummary] {
        folders(in: homeId).map { folder in
            let descendantIDs = descendantFolderIDs(for: folder.id, homeId: homeId)
            let allFolderIDs = descendantIDs.union([folder.id])
            return RecipeFolderSummary(
                folder: folder,
                recipeCount: dbFolderAssignments.filter { allFolderIDs.contains($0.folderId) }.count,
                descendantCount: descendantIDs.count
            )
        }
    }

    public func tagSummaries(homeId: UUID?) -> [RecipeTagSummary] {
        tags(in: homeId).map { tag in
            RecipeTagSummary(
                tag: tag,
                recipeCount: dbTagAssignments.filter { $0.tagId == tag.id }.count
            )
        }
    }

    public func folders(in homeId: UUID?) -> [RecipeFolder] {
        folders.filter { $0.homeId == homeId }
    }

    public func folders(parentFolderId: UUID?, homeId: UUID?) -> [RecipeFolder] {
        folders(in: homeId).filter { $0.parentFolderId == parentFolderId }
    }

    public func folder(id: UUID?) -> RecipeFolder? {
        guard let id else { return nil }
        return folders.first { $0.id == id }
    }

    public func descendantFolderIDs(for folderID: UUID, homeId: UUID?) -> Set<UUID> {
        let children = folders(parentFolderId: folderID, homeId: homeId)
        return children.reduce(Set(children.map(\.id))) { partialResult, child in
            partialResult.union(descendantFolderIDs(for: child.id, homeId: homeId))
        }
    }

    public func tags(in homeId: UUID?) -> [RecipeTag] {
        tags.filter { $0.homeId == homeId }
    }

    public func currentFolderIDs(for recipeId: UUID) -> Set<UUID> {
        Set(dbFolderAssignments.filter { $0.recipeId == recipeId }.map(\.folderId))
    }

    public func currentTagIDs(for recipeId: UUID) -> Set<UUID> {
        Set(dbTagAssignments.filter { $0.recipeId == recipeId }.map(\.tagId))
    }

    @discardableResult
    public func createFolder(name rawName: String, homeId: UUID?, parentFolderId: UUID? = nil) async throws -> RecipeFolder? {
        let name = sanitized(rawName)
        guard !name.isEmpty else { return nil }

        let nextSortIndex = (folders(parentFolderId: parentFolderId, homeId: homeId).map(\.sortIndex).max() ?? -1) + 1
        let now = Date()
        let folder = DBRecipeFolder(
            id: UUID(),
            homeId: homeId,
            name: name,
            symbolName: suggestedFolderSymbol(for: name),
            colorHex: suggestedColorHex(for: name),
            sortIndex: nextSortIndex,
            createdAt: now,
            modifiedAt: now
        )

        try await database.write { db in
            try DBRecipeFolder.insert { folder }.execute(db)
            if let parentFolderId {
                try DBRecipeFolderHierarchy
                    .insert { DBRecipeFolderHierarchy(id: UUID(), parentFolderId: parentFolderId, childFolderId: folder.id) }
                    .execute(db)
            }
        }

        return folder.toDomainModel()
    }

    public func updateFolder(_ folder: RecipeFolder, name rawName: String) async throws {
        let name = sanitized(rawName)
        guard !name.isEmpty else { return }

        let symbolName = suggestedFolderSymbol(for: name)
        let colorHex = suggestedColorHex(for: name)
        let modifiedAt = Date()

        try await database.write { db in
            try DBRecipeFolder.find(folder.id).update {
                $0.name = #bind(name)
                $0.symbolName = #bind(symbolName)
                $0.colorHex = #bind(colorHex)
                $0.modifiedAt = #bind(modifiedAt)
            }
            .execute(db)
        }
    }

    public func deleteFolder(_ folder: RecipeFolder) async throws {
        let folderIDsToDelete = Array(descendantFolderIDs(for: folder.id, homeId: folder.homeId).union([folder.id]))
        try await database.write { db in
            try DBRecipeFolderAssignment
                .where { folderIDsToDelete.contains($0.folderId) }
                .delete()
                .execute(db)

            try DBRecipeFolderHierarchy
                .where { folderIDsToDelete.contains($0.parentFolderId) || folderIDsToDelete.contains($0.childFolderId) }
                .delete()
                .execute(db)

            try DBRecipeFolder
                .where { folderIDsToDelete.contains($0.id) }
                .delete()
                .execute(db)
        }
    }

    @discardableResult
    public func createTag(name rawName: String, homeId: UUID?) async throws -> RecipeTag? {
        let name = sanitized(rawName)
        guard !name.isEmpty else { return nil }
        if let existing = tags(in: homeId).first(where: { $0.name.caseInsensitiveCompare(name) == .orderedSame }) {
            return existing
        }

        let now = Date()
        let tag = DBRecipeTag(
            id: UUID(),
            homeId: homeId,
            name: name,
            colorHex: suggestedColorHex(for: name),
            createdAt: now,
            modifiedAt: now
        )

        try await database.write { db in
            try DBRecipeTag.insert { tag }.execute(db)
        }

        return tag.toDomainModel()
    }

    public func updateTag(_ tag: RecipeTag, name rawName: String) async throws {
        let name = sanitized(rawName)
        guard !name.isEmpty else { return }
        let colorHex = suggestedColorHex(for: name)
        let modifiedAt = Date()

        try await database.write { db in
            try DBRecipeTag.find(tag.id).update {
                $0.name = #bind(name)
                $0.colorHex = #bind(colorHex)
                $0.modifiedAt = #bind(modifiedAt)
            }
            .execute(db)
        }
    }

    public func deleteTag(_ tag: RecipeTag) async throws {
        try await database.write { db in
            try DBRecipeTag.find(tag.id).delete().execute(db)
        }
    }

    public func setOrganization(for recipe: Recipe, folderIDs: Set<UUID>, tagIDs: Set<UUID>) async throws {
        let now = Date()
        let existingFolderIDs = currentFolderIDs(for: recipe.id)
        let existingTagIDs = currentTagIDs(for: recipe.id)
        let folderIDsToInsert = folderIDs.subtracting(existingFolderIDs)
        let tagIDsToInsert = tagIDs.subtracting(existingTagIDs)
        let folderIDsToDelete = existingFolderIDs.subtracting(folderIDs)
        let tagIDsToDelete = existingTagIDs.subtracting(tagIDs)
        let folderDeleteIDs = Array(folderIDsToDelete)
        let tagDeleteIDs = Array(tagIDsToDelete)

        let folderInserts = folderIDsToInsert.map {
            DBRecipeFolderAssignment(id: UUID(), recipeId: recipe.id, folderId: $0, assignedAt: now)
        }
        let tagInserts = tagIDsToInsert.map {
            DBRecipeTagAssignment(id: UUID(), recipeId: recipe.id, tagId: $0, assignedAt: now)
        }

        try await database.write { db in
            if !folderDeleteIDs.isEmpty {
                try DBRecipeFolderAssignment
                    .where { $0.recipeId.eq(recipe.id) && folderDeleteIDs.contains($0.folderId) }
                    .delete()
                    .execute(db)
            }

            if !tagDeleteIDs.isEmpty {
                try DBRecipeTagAssignment
                    .where { $0.recipeId.eq(recipe.id) && tagDeleteIDs.contains($0.tagId) }
                    .delete()
                    .execute(db)
            }

            if !folderInserts.isEmpty {
                try DBRecipeFolderAssignment.insert { folderInserts }.execute(db)
            }

            if !tagInserts.isEmpty {
                try DBRecipeTagAssignment.insert { tagInserts }.execute(db)
            }
        }
    }

    public func suggestedTags(for recipe: Recipe, in homeId: UUID?) -> [RecipeTag] {
        let normalizedExisting = Set(recipe.tags.map { $0.name.localizedLowercase })
        let suggestions = suggestedTagNames(for: recipe)

        return tags(in: homeId).filter { tag in
            suggestions.contains(tag.name.localizedLowercase) && !normalizedExisting.contains(tag.name.localizedLowercase)
        }
    }

    private func sanitized(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
    }

    private func suggestedTagNames(for recipe: Recipe) -> Set<String> {
        var tags = Set<String>()
        let text = [recipe.title, recipe.description, recipe.author]
            .compactMap { $0 }
            .joined(separator: " ")
            .localizedLowercase

        let mappings: [(String, String)] = [
            ("breakfast", "breakfast"),
            ("brunch", "brunch"),
            ("lunch", "lunch"),
            ("dinner", "dinner"),
            ("dessert", "dessert"),
            ("cake", "baking"),
            ("bread", "baking"),
            ("cookie", "baking"),
            ("salad", "salad"),
            ("soup", "soup"),
            ("pasta", "pasta"),
            ("chicken", "chicken"),
            ("fish", "seafood"),
            ("prawn", "seafood"),
            ("shrimp", "seafood"),
            ("vegan", "vegan"),
            ("vegetarian", "vegetarian")
        ]

        for (needle, tag) in mappings where text.contains(needle) {
            tags.insert(tag)
        }

        if let totalTime = recipe.timing.totalTime ?? recipe.timing.cookTime, totalTime <= 30 {
            tags.insert("quick")
        }

        return tags
    }

    private func suggestedFolderSymbol(for name: String) -> String {
        let lowercased = name.localizedLowercase
        if lowercased.contains("work") || lowercased.contains("service") { return "briefcase" }
        if lowercased.contains("test") || lowercased.contains("development") { return "flask" }
        if lowercased.contains("bake") || lowercased.contains("dessert") { return "birthday.cake" }
        if lowercased.contains("quick") || lowercased.contains("weeknight") { return "bolt" }
        if lowercased.contains("menu") || lowercased.contains("event") { return "list.bullet.clipboard" }
        return "folder"
    }

    private func suggestedColorHex(for name: String) -> String {
        let colors = ["#2563EB", "#059669", "#D97706", "#DC2626", "#7C3AED", "#0891B2", "#BE123C"]
        let folded = name.unicodeScalars.reduce(0) { $0 + Int($1.value) }
        return colors[folded % colors.count]
    }
}
