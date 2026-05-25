//
//  RecipeDiscoverySourceSignals.swift
//  RecipesList
//

import Foundation
import Models

struct RecipeDiscoverySourceSignals: Sendable {
    let sourceDomains: [String]
    let existingRecipeUrls: [String]
}

enum RecipeDiscoverySourceSignalBuilder {
    static func build(from recipes: [Recipe]) -> RecipeDiscoverySourceSignals {
        let urls = recipes
            .map(\.sourceUrl)
            .filter(isExternalWebURL)
            .uniquedCaseInsensitive()

        let domains = urls
            .compactMap(domain)
            .reduce(into: [String: Int]()) { counts, domain in
                counts[domain, default: 0] += 1
            }
            .sorted { lhs, rhs in
                if lhs.value == rhs.value {
                    return lhs.key.localizedCaseInsensitiveCompare(rhs.key) == .orderedAscending
                }
                return lhs.value > rhs.value
            }
            .prefix(10)
            .map(\.key)

        return RecipeDiscoverySourceSignals(
            sourceDomains: Array(domains),
            existingRecipeUrls: Array(urls.prefix(400))
        )
    }

    private static func isExternalWebURL(_ value: String) -> Bool {
        guard let url = URL(string: value),
              let scheme = url.scheme?.lowercased() else {
            return false
        }
        return scheme == "http" || scheme == "https"
    }

    private static func domain(from value: String) -> String? {
        guard let host = URL(string: value)?.host(percentEncoded: false)?.lowercased() else {
            return nil
        }

        if host.hasPrefix("www.") {
            return String(host.dropFirst(4))
        }

        return host
    }
}

private extension Array where Element == String {
    func uniquedCaseInsensitive() -> [String] {
        var seen = Set<String>()
        var output: [String] = []

        for value in self {
            let key = value.lowercased()
            guard !seen.contains(key) else { continue }
            seen.insert(key)
            output.append(value)
        }

        return output
    }
}
