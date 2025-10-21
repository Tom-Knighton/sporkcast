//
//  RecipeStepIngredientMap.swift
//  Design
//
//  Created by Tom Knighton on 21/09/2025.
//

import API
import Foundation
import NaturalLanguage

public struct IngredientMatchingConfig: Sendable{
    let stopWords: Set<String>
    let prepWords: Set<String>
    let allowShortTokens: Set<String>
    let unitWords: Set<String>
    let synonyms: [String: [String]]
    let maxVariantTokens: ClosedRange<Int>
    let lowInfoHeads: Set<String>
    
    public init(stopWords: Set<String>, prepWords: Set<String>, allowShortTokens: Set<String>, unitWords: Set<String>, synonyms: [String : [String]], lowInfoHeads: Set<String>, maxVariantTokens: ClosedRange<Int>) {
        self.stopWords = stopWords
        self.prepWords = prepWords
        self.allowShortTokens = allowShortTokens
        self.unitWords = unitWords
        self.synonyms = synonyms
        self.maxVariantTokens = maxVariantTokens
        self.lowInfoHeads = lowInfoHeads
    }
    
    public static let shared = IngredientMatchingConfig(
        stopWords: [
            "a","an","the","of","to","into","in","on","and","or","with","for","from",
            "as","at","by","up","down","over","under"
        ],
        prepWords: [
            "peeled","grated","diced","minced","sliced","chopped","crushed","ground",
            "boneless","skinless","fresh","dried","large","small","medium","optional",
            "garnish","finely","roughly","thinly"
        ],
        allowShortTokens: [
            "egg","soy","ale","tea"
        ],
        unitWords: [
            "g","gram","grams","kg","ml","milliliter","milliliters","l","tbsp","tablespoon",
            "tsp","teaspoon","cup","cups","clove","cloves","pinch","dash","ounce","oz"
        ],
        synonyms: [
            "rapeseed oil": ["canola oil"],
            "spring onion": ["scallion","green onion"],
            "coriander": ["cilantro"],
            "eggplant": ["aubergine"]
        ],
        lowInfoHeads: ["oil","sauce","rice","flour","sugar","onion","pepper","chili","chilli"],
        maxVariantTokens: 1...3)
}

public struct IngredientStepMatcher {
    
    public init() {}
    
    public func matchIngredients(for step: RecipeStep, ingredients: [RecipeIngredient], config: IngredientMatchingConfig = .shared) -> [RecipeIngredient] {
        let norm = normalise(step)
        
        let ingredientVariants: [(ingredient: RecipeIngredient, variants: [String])] = ingredients.map { ing in
            let v = Array(generateVariants(for: ing, config: config))
                .sorted { $0.count > $1.count }
            return (ing, v)
        }
        
        var matchedWithIndex: [(ingredient: RecipeIngredient, index: Int)] = []

        for (ing, variants) in ingredientVariants {
            var bestIndex: Int? = nil
            for variant in variants {
                let tokenCount = variant.split(separator: " ").count
                if tokenCount == 1 {
                    let token = variant
                    if token.count < 3 && !config.allowShortTokens.contains(token) { continue }
                    if config.stopWords.contains(token) { continue }
                    if let idx = norm.lemmaTokens.firstIndex(of: String(token)) {
                        bestIndex = min(bestIndex ?? idx, idx)
                    }
                } else {
                    let vTokens = variant.split(separator: " ").map(String.init)
                    if let idx = firstSpanIndex(of: vTokens, in: norm.lemmaTokens) {
                        bestIndex = min(bestIndex ?? idx, idx)
                    }
                }
            }
            
            if let idx = bestIndex {
                matchedWithIndex.append((ing, idx))
            }
        }
        
        matchedWithIndex.sort { $0.index < $1.index }
        return matchedWithIndex.map { $0.ingredient }
    }
    
    private func tokenize(_ s: String) -> [String] {
        s.split(whereSeparator: { !$0.isLetter }).map { String($0) }
    }
    
    private func normalise(_ step: RecipeStep) -> NormalisedStep {
        let lower = decodeHTML(step.instructionText.lowercased())
        let cleaned = lettersAndSeparatorsOnly(lower)
        let lemmas = lemmaTokens(cleaned)
        let tokenSet = Set(lemmas)
        
        let normalisedText = " \(lemmas.joined(separator: " ")) "
        
        return .init(normalisedText: normalisedText, lemmaTokens: lemmas, tokenSet: tokenSet)
    }
    
    private func normaliseIngredient(_ ing: String, config: IngredientMatchingConfig = .shared) -> String {
        let lower = ing.lowercased()
        let stripped = lower
            .replacingOccurrences(of: #"\(.*?\)"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\[.*?\]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #",.*$"#, with: " ", options: .regularExpression)
        let cleaned = lettersAndSeparatorsOnly(stripped)
        let tokens = tokenize(cleaned).filter { token in
            guard !token.isEmpty else { return false }
            if config.unitWords.contains(token) { return false }
            if Int(token) != nil { return false }
            
            return true
        }
        
        return tokens.joined(separator: " ")
    }
    
    private func decodeHTML(_ step: String) -> String {
        let replaced = step.replacingOccurrences(of: "&amp;", with: "&")
        
        return replaced
    }
    
    private func lettersAndSeparatorsOnly(_ step: String) -> String {
        let filtered = step.unicodeScalars.map { scalar -> Character in
            if CharacterSet.letters.contains(scalar) || scalar == " " || scalar == "/" || scalar == "&" || scalar == "-" {
                return Character(scalar)
            } else {
                return " "
            }
        }
        return String(filtered).replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
    }
    
    private func lemmaTokens(_ step: String, locale: Locale = .current) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = step
        var lemmas: [String] = []
        
        tagger.enumerateTags(in: step.startIndex..<step.endIndex, unit: .word, scheme: .lemma, options: [.omitPunctuation, .omitWhitespace]) { tag, range in
            let surface = step[range].lowercased()
            let lemma = (tag?.rawValue ?? surface).lowercased()
            lemmas.append(lemma)
            return true
        }
        
        return lemmas
    }
    
    private func firstSpanIndex(of variantTokens: [String], in stepTokens: [String]) -> Int? {
        guard !variantTokens.isEmpty, variantTokens.count <= stepTokens.count else { return nil }
        let vLen = variantTokens.count
        var i = 0
        while i + vLen <= stepTokens.count {
            if stepTokens[i..<(i+vLen)].elementsEqual(variantTokens) {
                return i
            }
            i += 1
        }
        return nil
    }
    
    public func generateVariants(for ingredient: RecipeIngredient, config: IngredientMatchingConfig = .shared) -> Set<String> {
        let sources: [String] = [ingredient.ingredientPart, ingredient.ingredientText, ingredient.extraInformation, ingredient.unit?.unitText, ingredient.quantity?.quantityText]
            .compactMap { $0 }
            .filter { !$0.isEmpty }
        
        var variants = Set<String>()
        
        for source in sources {
            let lower = source.lowercased()
            let stripped = lower
                .replacingOccurrences(of: #"\(.*?\)"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\[.*?\]"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #",.*$"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let rawParts = stripped.split(whereSeparator: { "/&-".contains($0) }).map { String($0) }
            let parts = rawParts.map(lettersAndSeparatorsOnly).map { $0.trimmingCharacters(in: .whitespaces) }.filter { !$0.isEmpty }
            guard !parts.isEmpty else { continue }
            
            let expanded: [String] = parts.count >= 2 ? parts + [parts.joined(separator: " ")] : parts
            
            
            for phrase in expanded {
                let lemmas = lemmaTokens(phrase)
                let filtered = lemmas.filter { token in
                    if config.stopWords.contains(token) { return false }
                    if config.prepWords.contains(token) { return false }
                    if config.unitWords.contains(token) { return false }
                    if token.count < 3 && !config.allowShortTokens.contains(token) { return false }
                    return true
                }
                guard !filtered.isEmpty else { continue }
                
                let forbidLowInfoSingles = filtered.count >= 2
                
                for n in config.maxVariantTokens {
                    guard filtered.count >= n else { continue }
                    for i in 0...(filtered.count - n) {
                        let ngramTokens = Array(filtered[i..<(i+n)])
                        if n == 1, forbidLowInfoSingles, let t = ngramTokens.first, config.lowInfoHeads.contains(t) {
                            continue
                        }
                        variants.insert(ngramTokens.joined(separator: " "))
                    }
                }
                
                if filtered.count <= config.maxVariantTokens.upperBound {
                    let joined = filtered.joined(separator: " ")
                    variants.insert(joined)
                    if let syns = config.synonyms[joined] {
                        for syn in syns { variants.insert(syn) }
                    }
                }
            }
        }
        
        return variants
    }
    
    struct NormalisedStep {
        let normalisedText: String
        let lemmaTokens: [String]
        let tokenSet: Set<String>
    }
}
