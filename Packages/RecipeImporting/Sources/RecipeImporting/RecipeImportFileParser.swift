//
//  RecipeImportFileParser.swift
//  RecipeImporting
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import ZIPFoundation

struct RecipeImportFileParser {

    func parse(fileURL: URL, vendorHint: RecipeImportVendor? = nil) throws -> [ParsedImportRecord] {
        let hasSecurityScopedAccess = fileURL.startAccessingSecurityScopedResource()
        defer {
            if hasSecurityScopedAccess {
                fileURL.stopAccessingSecurityScopedResource()
            }
        }

        let ext = fileURL.pathExtension.lowercased()

        switch ext {
        case "md", "markdown", "txt":
            return try parseMarkdownFile(fileURL: fileURL, mode: .markdown, sourceHint: fileURL.lastPathComponent)
        case "pestle":
            let data = try Data(contentsOf: fileURL)
            return try parseJSONData(
                data,
                vendor: resolveVendor(
                    fileName: fileURL.lastPathComponent,
                    vendorHint: vendorHint,
                    fallbackFileName: "pestle"
                ),
                mode: .file,
                sourceHint: fileURL.lastPathComponent
            )
        case "json":
            let data = try Data(contentsOf: fileURL)
            return try parseJSONData(
                data,
                vendor: resolveVendor(fileName: fileURL.lastPathComponent, vendorHint: vendorHint),
                mode: .file,
                sourceHint: fileURL.lastPathComponent
            )
        case "crumb":
            let data = try Data(contentsOf: fileURL)
            return try parseJSONData(
                data,
                vendor: resolveVendor(
                    fileName: fileURL.lastPathComponent,
                    vendorHint: vendorHint,
                    fallbackFileName: "crouton"
                ),
                mode: .file,
                sourceHint: fileURL.lastPathComponent
            )
        case "sporkast":
            let data = try Data(contentsOf: fileURL)
            return try parseJSONData(
                data,
                vendor: resolveVendor(
                    fileName: fileURL.lastPathComponent,
                    vendorHint: vendorHint,
                    fallbackFileName: "sporkcast"
                ),
                mode: .file,
                sourceHint: fileURL.lastPathComponent
            )
        case "zip", "paprikarecipes":
            let defaultHint: RecipeImportVendor? = ext == "paprikarecipes" ? .paprika : vendorHint
            return try parseZip(fileURL: fileURL, vendorHint: defaultHint)
        default:
            throw RecipeImportError.unsupportedFileType(ext)
        }
    }

    private func parseZip(fileURL: URL, vendorHint: RecipeImportVendor?) throws -> [ParsedImportRecord] {
        let archive: Archive
        do {
            archive = try Archive(url: fileURL, accessMode: .read)
        } catch {
            throw RecipeImportError.unreadableFile
        }

        var parsed: [ParsedImportRecord] = []
        let shouldParseMarkdownEntries = vendorHint == nil || vendorHint == .unknown

        for entry in archive {
            guard entry.type == .file else { continue }
            guard !entry.path.hasPrefix("__MACOSX") else { continue }

            var data = Data()
            _ = try archive.extract(entry) { chunk in
                data.append(chunk)
            }

            let pathExt = URL(fileURLWithPath: entry.path).pathExtension.lowercased()

            if pathExt == "json" || pathExt == "pestle" || pathExt == "crumb" || pathExt == "sporkast" {
                let vendor = resolveVendor(
                    fileName: entry.path,
                    vendorHint: vendorHint,
                    fallbackFileName: fileURL.lastPathComponent
                )

                let records = try parseJSONData(data, vendor: vendor, mode: .archive, sourceHint: entry.path)
                parsed.append(contentsOf: records)
            } else if shouldParseMarkdownEntries && (pathExt == "md" || pathExt == "markdown" || pathExt == "txt") {
                let markdownRecords = try parseMarkdownData(data, mode: .archive, sourceHint: entry.path)
                parsed.append(contentsOf: markdownRecords)
            }
        }

        return parsed
    }

    private func parseMarkdownFile(fileURL: URL, mode: RecipeImportMode, sourceHint: String) throws -> [ParsedImportRecord] {
        guard let data = try String(contentsOf: fileURL, encoding: .utf8).data(using: .utf8) else {
            throw RecipeImportError.unreadableFile
        }

        return try parseMarkdownData(data, mode: mode, sourceHint: sourceHint)
    }

    private func parseMarkdownData(
        _ data: Data,
        mode: RecipeImportMode,
        sourceHint: String
    ) throws -> [ParsedImportRecord] {
        guard let text = String(data: data, encoding: .utf8) else {
            throw RecipeImportError.unreadableFile
        }

        let records = MarkdownRecipeParser().parse(text)

        return records.map {
            ParsedImportRecord(
                record: $0,
                provenance: RecipeImportProvenance(mode: mode, vendor: .markdown, sourceHint: sourceHint),
                rawText: text
            )
        }
    }

    private func parseJSONData(
        _ data: Data,
        vendor: RecipeImportVendor,
        mode: RecipeImportMode,
        sourceHint: String
    ) throws -> [ParsedImportRecord] {
        guard let object = try? JSONSerialization.jsonObject(with: data) else {
            return []
        }

        let adapters = RecipeImportJSONAdapterRegistry.orderedAdapters(preferredVendor: vendor)

        for adapter in adapters {
            let records = adapter.parse(jsonObject: object)
            guard !records.isEmpty else { continue }

            let resolvedVendor: RecipeImportVendor = vendor == .unknown ? adapter.vendor : vendor
            return records.map { record in
                ParsedImportRecord(
                    record: record,
                    provenance: RecipeImportProvenance(mode: mode, vendor: resolvedVendor, sourceHint: sourceHint),
                    rawText: buildRawText(from: record)
                )
            }
        }

        return []
    }

    private func resolveVendor(
        fileName: String,
        vendorHint: RecipeImportVendor?,
        fallbackFileName: String? = nil
    ) -> RecipeImportVendor {
        if let vendorHint, vendorHint != .unknown {
            return vendorHint
        }

        let detected = detectVendor(fromFileName: fileName)
        if detected != .unknown {
            return detected
        }

        if let fallbackFileName {
            let fallback = detectVendor(fromFileName: fallbackFileName)
            if fallback != .unknown {
                return fallback
            }
        }

        return .unknown
    }

    private func detectVendor(fromFileName fileName: String) -> RecipeImportVendor {
        let lowered = fileName.lowercased()

        if lowered.hasSuffix(".pestle") || lowered.contains("pestle") {
            return .pestle
        }

        if lowered.hasSuffix(".crumb") || lowered.contains("crouton") {
            return .crouton
        }

        if lowered.hasSuffix(".paprikarecipes") || lowered.contains("paprika") {
            return .paprika
        }

        if lowered.hasSuffix(".sporkast") || lowered.contains("sporkcast") {
            return .sporkcast
        }

        return .unknown
    }

    private func buildRawText(from record: ImportedRecipeRecord) -> String {
        var lines: [String] = [record.title]

        if let description = record.description {
            lines.append(description)
        }

        let ingredients = record.ingredientSections.flatMap(\.ingredients)
        if !ingredients.isEmpty {
            lines.append("Ingredients:")
            lines.append(contentsOf: ingredients)
        }

        let steps = record.stepSections.flatMap(\.steps)
        if !steps.isEmpty {
            lines.append("Method:")
            lines.append(contentsOf: steps)
        }

        return lines.joined(separator: "\n")
    }
}
