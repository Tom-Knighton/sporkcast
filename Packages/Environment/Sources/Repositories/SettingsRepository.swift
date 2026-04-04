//
//  SettingsRepository.swift
//  Persistence
//
//  Created by Tom Knighton on 2025-12-30.
//

import Dependencies
import Foundation
import Observation
import SQLiteData
import Persistence
import ZIPFoundation

@Observable
@MainActor
public final class SettingsRepository {

    @ObservationIgnored
    @Dependency(\.defaultDatabase) private var database

    public init() {}

    public func deleteAllData() async throws {
        try await database.write { db in
            try DBHome.delete().execute(db)
            try DBRecipe.delete().execute(db)
            try SyncMetadata.delete().execute(db)
            try DBMealplanEntry.delete().execute(db)
        }
    }

    public func exportDatabase() async throws -> URL {
        let tmpDir = FileManager.default.temporaryDirectory
        let exportURL = tmpDir.appendingPathComponent("export.sqlite")
        if FileManager.default.fileExists(atPath: exportURL.path) {
            try FileManager.default.removeItem(at: exportURL)
        }

        try await database.write { try $0.execute(sql: "VACUUM INTO ?", arguments: [exportURL.path]) }
        return exportURL
    }

    public func exportRecipes(as format: RecipeExportFormat = .sporkast) async throws -> RecipeExportPackage {
        let recipes = try await database.read { db in
            try DBRecipe.full.fetchAll(db)
        }

        guard !recipes.isEmpty else {
            throw RecipeExportError.noRecipesAvailable
        }

        let exportedAt = Date.now
        return try await Task.detached(priority: .utility) {
            try Self.makeRecipeExportPackage(
                from: recipes,
                format: format,
                exportedAt: exportedAt
            )
        }.value
    }
}

private extension SettingsRepository {
    nonisolated static func makeRecipeExportPackage(
        from recipes: [FullDBRecipe],
        format: RecipeExportFormat,
        exportedAt: Date
    ) throws -> RecipeExportPackage {
        let exportDirectory = try makeExportDirectory(format: format, exportedAt: exportedAt)
        let sortedRecipes = recipes.sorted(by: recipeExportSortOrder)
        var fileURLs: [URL] = []
        fileURLs.reserveCapacity(sortedRecipes.count)

        for (index, recipe) in sortedRecipes.enumerated() {
            let fileName = makeExportFileName(for: recipe.recipe, index: index)
            let fileURL = exportDirectory
                .appendingPathComponent(fileName)
                .appendingPathExtension(format.fileExtension)
            let exportData = try makeExportData(for: recipe, format: format, exportedAt: exportedAt)
            try exportData.write(to: fileURL, options: [.atomic])
            fileURLs.append(fileURL)
        }

        let archiveURL = try makeArchive(
            from: exportDirectory,
            format: format,
            exportedAt: exportedAt
        )

        return RecipeExportPackage(
            format: format,
            exportedAt: exportedAt,
            directoryURL: exportDirectory,
            archiveURL: archiveURL,
            fileURLs: fileURLs,
            cleanupURLs: [archiveURL, exportDirectory]
        )
    }

    nonisolated static func makeExportDirectory(format: RecipeExportFormat, exportedAt: Date) throws -> URL {
        let fileManager = FileManager.default
        let rootDirectory = fileManager.temporaryDirectory.appendingPathComponent("sporkcast-exports", isDirectory: true)
        try fileManager.createDirectory(at: rootDirectory, withIntermediateDirectories: true)

        let timestamp = String(Int(exportedAt.timeIntervalSince1970))
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let exportDirectory = rootDirectory.appendingPathComponent(
            "\(format.directoryPrefix)-\(timestamp)-\(suffix)",
            isDirectory: true
        )
        try fileManager.createDirectory(at: exportDirectory, withIntermediateDirectories: true)
        return exportDirectory
    }

    nonisolated static func makeArchive(
        from exportDirectory: URL,
        format: RecipeExportFormat,
        exportedAt: Date
    ) throws -> URL {
        let timestamp = String(Int(exportedAt.timeIntervalSince1970))
        let suffix = UUID().uuidString.lowercased().prefix(8)
        let archiveURL = exportDirectory
            .deletingLastPathComponent()
            .appendingPathComponent("\(format.directoryPrefix)-\(timestamp)-\(suffix)")
            .appendingPathExtension("zip")

        if FileManager.default.fileExists(atPath: archiveURL.path) {
            try FileManager.default.removeItem(at: archiveURL)
        }

        let archive: Archive
        do {
            archive = try Archive(url: archiveURL, accessMode: .create)
        } catch {
            throw RecipeExportError.failedToCreateArchive
        }

        let files = try FileManager.default.contentsOfDirectory(
            at: exportDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ).sorted { $0.lastPathComponent.localizedCaseInsensitiveCompare($1.lastPathComponent) == .orderedAscending }

        for fileURL in files {
            try archive.addEntry(
                with: fileURL.lastPathComponent,
                relativeTo: exportDirectory,
                compressionMethod: .deflate
            )
        }

        return archiveURL
    }

    nonisolated static func makeExportData(
        for recipe: FullDBRecipe,
        format: RecipeExportFormat,
        exportedAt: Date
    ) throws -> Data {
        switch format {
        case .sporkast:
            let payload = SporkastRecipeExportPayload(
                recipe: recipe,
                exportedAt: exportedAt,
                schemaVersion: format.schemaVersion
            )
            do {
                return try recipeEncoder.encode(payload)
            } catch {
                throw RecipeExportError.failedToEncodeRecipe(recipeId: recipe.id)
            }
        }
    }

    nonisolated static func makeExportFileName(for recipe: DBRecipe, index: Int) -> String {
        let order = String(format: "%03d", index + 1)
        let title = sanitizeFileNameComponent(recipe.title)
        let idSuffix = recipe.id.uuidString.lowercased().prefix(8)
        return "\(order)-\(title)-\(idSuffix)"
    }

    nonisolated static func sanitizeFileNameComponent(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "recipe" }

        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-_ "))
        let filteredScalars = trimmed.unicodeScalars.map { scalar in
            allowed.contains(scalar) ? Character(scalar) : "-"
        }
        let withHyphens = String(filteredScalars).replacingOccurrences(of: " ", with: "-")
        let deduplicated = withHyphens.replacingOccurrences(of: "-{2,}", with: "-", options: .regularExpression)
        let cleaned = deduplicated
            .trimmingCharacters(in: CharacterSet(charactersIn: "-_"))
            .lowercased()
        return cleaned.isEmpty ? "recipe" : cleaned
    }

    nonisolated static func recipeExportSortOrder(lhs: FullDBRecipe, rhs: FullDBRecipe) -> Bool {
        let titleComparison = lhs.recipe.title.localizedCaseInsensitiveCompare(rhs.recipe.title)
        if titleComparison != .orderedSame {
            return titleComparison == .orderedAscending
        }
        return lhs.recipe.id.uuidString < rhs.recipe.id.uuidString
    }

    nonisolated static var recipeEncoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        return encoder
    }
}
