//
//  SyntheticSourceURL.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import CryptoKit

public struct SyntheticSourceDescriptor: Sendable, Hashable {
    public let mode: RecipeImportMode
    public let vendor: RecipeImportVendor
    public let key: String

    public init(mode: RecipeImportMode, vendor: RecipeImportVendor, key: String) {
        self.mode = mode
        self.vendor = vendor
        self.key = key
    }
}

public enum SyntheticSourceURL {
    public static func make(
        mode: RecipeImportMode,
        vendor: RecipeImportVendor,
        seed: String
    ) -> String {
        let normalized = seed.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let digest = SHA256.hash(data: Data(normalized.utf8))
        let key = digest.map { String(format: "%02x", $0) }.joined()
        return "sporkcast://import/\(mode.rawValue)/\(vendor.rawValue)/\(key)"
    }

    public static func isExternalWebURL(_ rawValue: String) -> Bool {
        guard let url = URL(string: rawValue), let scheme = url.scheme?.lowercased() else { return false }
        return scheme == "http" || scheme == "https"
    }

    public static func parse(_ rawValue: String) -> SyntheticSourceDescriptor? {
        guard let url = URL(string: rawValue) else { return nil }
        guard url.scheme?.lowercased() == "sporkcast" else { return nil }
        guard url.host?.lowercased() == "import" else { return nil }

        let components = url.path
            .split(separator: "/")
            .map(String.init)
        guard components.count >= 3 else { return nil }

        guard let mode = RecipeImportMode(rawValue: components[0]) else {
            return nil
        }

        guard let vendor = RecipeImportVendor(rawValue: components[1]) else {
            return nil
        }

        let key = components[2]
        guard !key.isEmpty else { return nil }

        return SyntheticSourceDescriptor(mode: mode, vendor: vendor, key: key)
    }
}
