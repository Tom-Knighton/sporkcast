//
//  RecipeSearchNormalizer.swift
//  Environment
//
//  Created by Tom Knighton on 12/07/2026.
//

import Foundation

public enum RecipeSearchNormalizer {
    private static let ignoredWords: Set<String> = [
        "a",
        "about",
        "an",
        "and",
        "any",
        "cook",
        "cooking",
        "cookbook",
        "find",
        "for",
        "in",
        "ingredient",
        "ingredients",
        "look",
        "matching",
        "me",
        "of",
        "one",
        "ones",
        "recipe",
        "recipes",
        "search",
        "show",
        "sporkcast",
        "sporkast",
        "that",
        "the",
        "up",
        "using",
        "with"
    ]

    public static func normalizedQuery(_ query: String) -> String {
        tokens(for: query).joined(separator: " ")
    }

    public static func tokens(for query: String) -> [String] {
        normalizedWords(in: query)
            .filter { !ignoredWords.contains($0) }
            .map(singularized)
            .removingDuplicates()
    }

    public static func matches(_ text: String, tokens: [String]) -> Bool {
        guard !tokens.isEmpty else { return true }

        let searchableText = normalizedSearchText(text)
        return tokens.allSatisfy { token in
            searchableText.contains(token) || searchableText.contains(pluralized(token))
        }
    }

    public static func normalizedSearchText(_ text: String) -> String {
        normalizedWords(in: text)
            .map(singularized)
            .joined(separator: " ")
    }

    private static func normalizedWords(in text: String) -> [String] {
        text
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
    }

    private static func singularized(_ word: String) -> String {
        guard word.count > 3, word.hasSuffix("s") else { return word }
        guard !word.hasSuffix("ss") else { return word }
        return String(word.dropLast())
    }

    private static func pluralized(_ word: String) -> String {
        word.hasSuffix("s") ? word : "\(word)s"
    }
}

private extension Array where Element: Hashable {
    func removingDuplicates() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
