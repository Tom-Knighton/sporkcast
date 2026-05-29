//
//  RecipeDebugLogStore.swift
//  Environment
//
//  Created by Codex on 29/05/2026.
//

import Foundation

public final class RecipeDebugLogStore: @unchecked Sendable {
    public static let shared = RecipeDebugLogStore()

    private let queue = DispatchQueue(label: "online.tomk.sporkcast.recipe-debug-log")
    private let fileManager = FileManager.default
    private let maxLogSizeBytes = 3 * 1024 * 1024

    public var logFileURL: URL {
        logDirectoryURL.appendingPathComponent("recipe-debug.log")
    }

    private var oldLogFileURL: URL {
        logDirectoryURL.appendingPathComponent("recipe-debug.old.log")
    }

    private var logDirectoryURL: URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? fileManager.temporaryDirectory
        return appSupport.appendingPathComponent("RecipeDebugLogs", isDirectory: true)
    }

    private init() {}

    public func log(_ message: @autoclosure @escaping @Sendable () -> String) {
        let timestamp = Self.timestamp()
        queue.async { [self] in
            appendLine("[\(timestamp)] \(message())")
        }
    }

    public func logSync(_ message: @autoclosure @escaping @Sendable () -> String) {
        let timestamp = Self.timestamp()
        queue.sync { [self] in
            appendLine("[\(timestamp)] \(message())")
        }
    }

    public func makeExportFile() throws -> URL {
        try queue.sync {
            try ensureLogDirectoryExists()

            let exportURL = fileManager.temporaryDirectory
                .appendingPathComponent("sporkcast-recipe-debug-\(Int(Date().timeIntervalSince1970))")
                .appendingPathExtension("log")

            if fileManager.fileExists(atPath: exportURL.path) {
                try fileManager.removeItem(at: exportURL)
            }

            var data = Data()
            if fileManager.fileExists(atPath: oldLogFileURL.path) {
                data.append(try Data(contentsOf: oldLogFileURL))
                data.append(Self.separatorData)
            }
            if fileManager.fileExists(atPath: logFileURL.path) {
                data.append(try Data(contentsOf: logFileURL))
            }
            if data.isEmpty {
                data.append(Data("No recipe debug logs have been recorded yet.\n".utf8))
            }

            try data.write(to: exportURL, options: [.atomic])
            return exportURL
        }
    }

    public func deleteLogs() {
        queue.async { [self] in
            try? fileManager.removeItem(at: logFileURL)
            try? fileManager.removeItem(at: oldLogFileURL)
        }
    }

    private func appendLine(_ line: String) {
        do {
            try ensureLogDirectoryExists()
            try rotateIfNeeded()

            let data = Data((line + "\n").utf8)
            if fileManager.fileExists(atPath: logFileURL.path) {
                let handle = try FileHandle(forWritingTo: logFileURL)
                defer { try? handle.close() }
                try handle.seekToEnd()
                try handle.write(contentsOf: data)
            } else {
                try data.write(to: logFileURL, options: [.atomic])
            }
        } catch {
            print("Failed to append recipe debug log: \(error)")
        }
    }

    private func ensureLogDirectoryExists() throws {
        try fileManager.createDirectory(
            at: logDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    private func rotateIfNeeded() throws {
        guard let attributes = try? fileManager.attributesOfItem(atPath: logFileURL.path),
              let size = attributes[.size] as? NSNumber,
              size.intValue >= maxLogSizeBytes
        else { return }

        if fileManager.fileExists(atPath: oldLogFileURL.path) {
            try fileManager.removeItem(at: oldLogFileURL)
        }
        try fileManager.moveItem(at: logFileURL, to: oldLogFileURL)
    }

    private static var separatorData: Data {
        Data("\n\n--- rotated log ---\n\n".utf8)
    }

    private static func timestamp() -> String {
        ISO8601DateFormatter().string(from: Date())
    }
}
