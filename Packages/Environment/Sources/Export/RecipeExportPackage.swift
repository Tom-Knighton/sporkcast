//
//  RecipeExportPackage.swift
//  Environment
//
//  Created by Tom Knighton on 03/04/2026.
//

import Foundation

public struct RecipeExportPackage: Sendable, Identifiable, Equatable {
    public let id: UUID
    public let format: RecipeExportFormat
    public let exportedAt: Date
    public let directoryURL: URL
    public let archiveURL: URL
    public let fileURLs: [URL]
    public let cleanupURLs: [URL]

    public var fileCount: Int { fileURLs.count }

    public init(
        id: UUID = UUID(),
        format: RecipeExportFormat,
        exportedAt: Date,
        directoryURL: URL,
        archiveURL: URL,
        fileURLs: [URL],
        cleanupURLs: [URL]
    ) {
        self.id = id
        self.format = format
        self.exportedAt = exportedAt
        self.directoryURL = directoryURL
        self.archiveURL = archiveURL
        self.fileURLs = fileURLs
        self.cleanupURLs = cleanupURLs
    }
}
