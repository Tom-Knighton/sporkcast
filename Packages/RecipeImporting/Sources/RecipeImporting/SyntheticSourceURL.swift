//
//  SyntheticSourceURL.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import CryptoKit

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
}
