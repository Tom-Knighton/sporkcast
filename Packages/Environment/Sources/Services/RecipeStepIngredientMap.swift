//
//  RecipeStepIngredientMap.swift
//  Design
//
//  Created by Tom Knighton on 21/09/2025.
//

import Foundation
import Models
import NaturalLanguage

public struct IngredientMatchingConfig: Sendable {
    let stopWords: Set<String>
    let prepWords: Set<String>
    let allowShortTokens: Set<String>
    let unitWords: Set<String>
    let synonyms: [String: [String]]
    let maxVariantTokens: ClosedRange<Int>
    let lowInfoHeads: Set<String>
    let allowModifierSinglesForHeads: Set<String>
    let ignoreVariantSourcesBeyondName: Bool
    
    public init(
        stopWords: Set<String>,
        prepWords: Set<String>,
        allowShortTokens: Set<String>,
        unitWords: Set<String>,
        synonyms: [String: [String]],
        lowInfoHeads: Set<String>,
        maxVariantTokens: ClosedRange<Int>,
        allowModifierSinglesForHeads: Set<String>,
        ignoreVariantSourcesBeyondName: Bool
    ) {
        self.stopWords = stopWords
        self.prepWords = prepWords
        self.allowShortTokens = allowShortTokens
        self.unitWords = unitWords
        self.synonyms = synonyms
        self.maxVariantTokens = maxVariantTokens
        self.lowInfoHeads = lowInfoHeads
        self.allowModifierSinglesForHeads = allowModifierSinglesForHeads
        self.ignoreVariantSourcesBeyondName = ignoreVariantSourcesBeyondName
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
        lowInfoHeads: ["oil","sauce","flour","sugar","pepper","chili","chilli"],
        maxVariantTokens: 1...3,
        allowModifierSinglesForHeads: [
            "breast","breasts","thigh","thighs","wing","wings","drumstick","drumsticks",
            "fillet","fillets","steak","steaks","mince"
        ],
        ignoreVariantSourcesBeyondName: true
    )
}

public enum IngredientMatchKind: String {
    case fullSpan
    case fullSingle
    case headSingle
    case modifierSingle
}

public struct IngredientMatchDebug {
    public let ingredient: RecipeIngredient
    public let matchedVariant: String?
    public let index: Int?
    public let spanLength: Int?
    public let kind: IngredientMatchKind?
    public let score: Int?
    public let selected: Bool
    public let reason: String
}

public struct IngredientMatchResult {
    public let ingredients: [RecipeIngredient]
    public let debug: [IngredientMatchDebug]
}

public struct IngredientStepMatcher {
    public init() {}
    
    public func matchIngredients(
        for stepText: String,
        ingredients: [RecipeIngredient],
        config: IngredientMatchingConfig = .shared
    ) -> [RecipeIngredient] {
        matchIngredients(for: stepText, ingredients: ingredients, config: config, debug: false).ingredients
    }
    
    public func matchIngredients(
        for stepText: String,
        ingredients: [RecipeIngredient],
        config: IngredientMatchingConfig = .shared,
        debug: Bool
    ) -> IngredientMatchResult {
        let norm = normalise(stepText)
        
        let canonTokensByIngredientIndex: [Int: [String]] = Dictionary(
            uniqueKeysWithValues: ingredients.enumerated().map { idx, ing in
                (idx, canonicalTokens(for: ing, config: config))
            }
        )
        
        let variantsByIngredientIndex: [Int: [String]] = Dictionary(
            uniqueKeysWithValues: ingredients.enumerated().map { idx, ing in
                let variants = Array(generateVariants(for: ing, config: config))
                    .sorted { $0.count > $1.count }
                return (idx, variants)
            }
        )
        
        var allCandidates: [Candidate] = []
        allCandidates.reserveCapacity(ingredients.count * 4)
        
        var bestCandidateByIngredientIndex: [Int: Candidate] = [:]
        
        for (ingredientIndex, variants) in variantsByIngredientIndex {
            let canonTokens = canonTokensByIngredientIndex[ingredientIndex] ?? []
            let head = canonTokens.last
            
            for variant in variants {
                let vTokens = variant.split(separator: " ").map(String.init)
                guard !vTokens.isEmpty else { continue }
                guard vTokens.allSatisfy(norm.tokenSet.contains) else { continue }
                
                if vTokens.count == 1 {
                    let token = vTokens[0]
                    guard token.count >= 3 || config.allowShortTokens.contains(token) else { continue }
                    guard !config.stopWords.contains(token) else { continue }
                    
                    let indices = allIndices(of: token, in: norm.lemmaTokens)
                    for idx in indices {
                        let kind = classifyKind(
                            canonTokens: canonTokens,
                            head: head,
                            matchedToken: token,
                            spanLength: 1
                        )
                        let score = scoreFor(
                            kind: kind,
                            spanLength: 1,
                            isExactCanonical: canonTokens.count == 1 && canonTokens.first == token
                        )
                        
                        let candidate = Candidate(
                            ingredientIndex: ingredientIndex,
                            variant: variant,
                            variantTokens: vTokens,
                            index: idx,
                            spanLength: 1,
                            kind: kind,
                            score: score
                        )
                        
                        allCandidates.append(candidate)
                        if let best = bestCandidateByIngredientIndex[ingredientIndex] {
                            if candidate.isBetterThan(best) {
                                bestCandidateByIngredientIndex[ingredientIndex] = candidate
                            }
                        } else {
                            bestCandidateByIngredientIndex[ingredientIndex] = candidate
                        }
                    }
                } else {
                    let indices = allSpanIndices(of: vTokens, in: norm.lemmaTokens, allowOverlapping: false)
                    for idx in indices {
                        let kind = classifyKind(
                            canonTokens: canonTokens,
                            head: head,
                            matchedToken: nil,
                            spanLength: vTokens.count
                        )
                        let isExactCanonical = canonTokens == vTokens
                        let score = scoreFor(kind: kind, spanLength: vTokens.count, isExactCanonical: isExactCanonical)
                        
                        let candidate = Candidate(
                            ingredientIndex: ingredientIndex,
                            variant: variant,
                            variantTokens: vTokens,
                            index: idx,
                            spanLength: vTokens.count,
                            kind: kind,
                            score: score
                        )
                        
                        allCandidates.append(candidate)
                        if let best = bestCandidateByIngredientIndex[ingredientIndex] {
                            if candidate.isBetterThan(best) {
                                bestCandidateByIngredientIndex[ingredientIndex] = candidate
                            }
                        } else {
                            bestCandidateByIngredientIndex[ingredientIndex] = candidate
                        }
                    }
                }
            }
        }
        
        allCandidates.sort { lhs, rhs in
            if lhs.score != rhs.score { return lhs.score > rhs.score }
            if lhs.spanLength != rhs.spanLength { return lhs.spanLength > rhs.spanLength }
            return lhs.index < rhs.index
        }
        
        var selectedCandidates: [Candidate] = []
        selectedCandidates.reserveCapacity(ingredients.count)
        
        var selectedIngredientIndices = Set<Int>()
        selectedIngredientIndices.reserveCapacity(ingredients.count)
        
        var suppressionReasonByIngredientIndex: [Int: String] = [:]
        
        var occupiedByTokenIndex: [Int: Candidate] = [:]
        occupiedByTokenIndex.reserveCapacity(norm.lemmaTokens.count)
        
        @inline(__always)
        func firstOccupier(over range: Range<Int>) -> Candidate? {
            for i in range {
                if let owner = occupiedByTokenIndex[i] { return owner }
            }
            return nil
        }
        
        func occupy(_ selected: Candidate) {
            if selected.spanLength <= 1 {
                occupiedByTokenIndex[selected.index] = selected
                return
            }
            
            guard selected.kind == .fullSpan else {
                for i in selected.range where occupiedByTokenIndex[i] == nil {
                    occupiedByTokenIndex[i] = selected
                }
                return
            }
            
            let starts = allSpanIndices(of: selected.variantTokens, in: norm.lemmaTokens, allowOverlapping: true)
            for start in starts {
                let r = start..<(start + selected.variantTokens.count)
                for i in r where occupiedByTokenIndex[i] == nil {
                    occupiedByTokenIndex[i] = selected
                }
            }
        }
        
        for candidate in allCandidates {
            if selectedIngredientIndices.contains(candidate.ingredientIndex) {
                continue
            }
            
            if let owner = firstOccupier(over: candidate.range) {
                suppressionReasonByIngredientIndex[candidate.ingredientIndex] = "suppressed by '\(owner.variant)'"
                continue
            }
            
            selectedCandidates.append(candidate)
            selectedIngredientIndices.insert(candidate.ingredientIndex)
            occupy(candidate)
        }
        
        selectedCandidates.sort { $0.index < $1.index }
        
        let matchedIngredients = selectedCandidates.map { ingredients[$0.ingredientIndex] }
        
        guard debug else {
            return IngredientMatchResult(ingredients: matchedIngredients, debug: [])
        }
        
        let selectedByIngredientIndex: [Int: Candidate] = Dictionary(
            uniqueKeysWithValues: selectedCandidates.map { ($0.ingredientIndex, $0) }
        )
        
        let debugItems: [IngredientMatchDebug] = ingredients.enumerated().map { idx, ing in
            if let selected = selectedByIngredientIndex[idx] {
                return IngredientMatchDebug(
                    ingredient: ing,
                    matchedVariant: selected.variant,
                    index: selected.index,
                    spanLength: selected.spanLength,
                    kind: selected.kind,
                    score: selected.score,
                    selected: true,
                    reason: "selected"
                )
            }
            
            if let best = bestCandidateByIngredientIndex[idx] {
                let reason = suppressionReasonByIngredientIndex[idx] ?? "not selected"
                return IngredientMatchDebug(
                    ingredient: ing,
                    matchedVariant: best.variant,
                    index: best.index,
                    spanLength: best.spanLength,
                    kind: best.kind,
                    score: best.score,
                    selected: false,
                    reason: reason
                )
            }
            
            return IngredientMatchDebug(
                ingredient: ing,
                matchedVariant: nil,
                index: nil,
                spanLength: nil,
                kind: nil,
                score: nil,
                selected: false,
                reason: "no match"
            )
        }
        
        return IngredientMatchResult(ingredients: matchedIngredients, debug: debugItems)
    }
    
    private struct Candidate {
        let ingredientIndex: Int
        let variant: String
        let variantTokens: [String]
        let index: Int
        let spanLength: Int
        let kind: IngredientMatchKind
        let score: Int
        
        func isBetterThan(_ other: Candidate) -> Bool {
            if score != other.score { return score > other.score }
            if spanLength != other.spanLength { return spanLength > other.spanLength }
            return index < other.index
        }
        
        var range: Range<Int> { index..<(index + spanLength) }
    }
    
    private func classifyKind(
        canonTokens: [String],
        head: String?,
        matchedToken: String?,
        spanLength: Int
    ) -> IngredientMatchKind {
        if spanLength >= 2 { return .fullSpan }
        if canonTokens.count <= 1 { return .fullSingle }
        
        if let matchedToken, matchedToken == head {
            return .headSingle
        }
        return .modifierSingle
    }
    
    private func scoreFor(kind: IngredientMatchKind, spanLength: Int, isExactCanonical: Bool) -> Int {
        let base: Int = switch kind {
        case .fullSpan: 1000
        case .fullSingle: 900
        case .headSingle: 700
        case .modifierSingle: 500
        }
        
        let spanBonus = spanLength >= 2 ? spanLength * 50 : 0
        let exactBonus = isExactCanonical ? 75 : 0
        return base + spanBonus + exactBonus
    }
    
    private func allIndices(of token: String, in stepTokens: [String]) -> [Int] {
        var out: [Int] = []
        out.reserveCapacity(2)
        for (i, t) in stepTokens.enumerated() where t == token {
            out.append(i)
        }
        return out
    }
    
    private func allSpanIndices(
        of variantTokens: [String],
        in stepTokens: [String],
        allowOverlapping: Bool
    ) -> [Int] {
        guard !variantTokens.isEmpty, variantTokens.count <= stepTokens.count else { return [] }
        
        let vLen = variantTokens.count
        var out: [Int] = []
        out.reserveCapacity(1)
        
        var i = 0
        while i + vLen <= stepTokens.count {
            if stepTokens[i..<(i + vLen)].elementsEqual(variantTokens) {
                out.append(i)
                i += allowOverlapping ? 1 : vLen
            } else {
                i += 1
            }
        }
        return out
    }
    
    private func normalise(_ step: String) -> NormalisedStep {
        let lower = decodeHTML(step.lowercased())
        let cleaned = lettersAndSeparatorsOnly(lower)
        let lemmas = lemmaTokens(cleaned)
        let tokenSet = Set(lemmas)
        let normalisedText = " \(lemmas.joined(separator: " ")) "
        return .init(normalisedText: normalisedText, lemmaTokens: lemmas, tokenSet: tokenSet)
    }
    
    private func decodeHTML(_ step: String) -> String {
        step.replacingOccurrences(of: "&amp;", with: "&")
    }
    
    private func lettersAndSeparatorsOnly(_ step: String) -> String {
        let filtered = step.unicodeScalars.map { scalar -> Character in
            if CharacterSet.letters.contains(scalar) || scalar == " " || scalar == "/" || scalar == "&" || scalar == "-" {
                return Character(scalar)
            }
            return " "
        }
        return String(filtered).replacingOccurrences(of: #" {2,}"#, with: " ", options: .regularExpression)
    }
    
    private func lemmaTokens(_ step: String, locale: Locale = .current) -> [String] {
        let tagger = NLTagger(tagSchemes: [.lemma])
        tagger.string = step
        
        var lemmas: [String] = []
        lemmas.reserveCapacity(32)
        
        tagger.enumerateTags(
            in: step.startIndex..<step.endIndex,
            unit: .word,
            scheme: .lemma,
            options: [.omitPunctuation, .omitWhitespace]
        ) { tag, range in
            let surface = step[range].lowercased()
            let lemma = (tag?.rawValue ?? surface).lowercased()
            lemmas.append(lemma)
            return true
        }
        
        return lemmas
    }
    
    private func canonicalTokens(for ingredient: RecipeIngredient, config: IngredientMatchingConfig) -> [String] {
        let sources: [String]
        if config.ignoreVariantSourcesBeyondName {
            sources = [ingredient.ingredientPart, ingredient.ingredientText]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
        } else {
            sources = [ingredient.ingredientPart, ingredient.ingredientText, ingredient.extraInformation]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
        }
        
        var best: [String] = []
        
        for source in sources {
            let lower = source.lowercased()
            let stripped = lower
                .replacingOccurrences(of: #"\(.*?\)"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\[.*?\]"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #",.*$"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let rawParts = stripped.split(whereSeparator: { "/&-".contains($0) }).map(String.init)
            let parts = rawParts
                .map(lettersAndSeparatorsOnly)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
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
                
                if filtered.count > best.count {
                    best = filtered
                }
            }
        }
        
        return best
    }
    
    public func generateVariants(for ingredient: RecipeIngredient, config: IngredientMatchingConfig = .shared) -> Set<String> {
        let sources: [String]
        
        if config.ignoreVariantSourcesBeyondName {
            sources = [ingredient.ingredientPart, ingredient.ingredientText]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
        } else {
            sources = [ingredient.ingredientPart, ingredient.ingredientText, ingredient.extraInformation]
                .compactMap { $0 }
                .filter { !$0.isEmpty }
        }
        
        var variants = Set<String>()
        
        for source in sources {
            let lower = source.lowercased()
            let stripped = lower
                .replacingOccurrences(of: #"\(.*?\)"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #"\[.*?\]"#, with: " ", options: .regularExpression)
                .replacingOccurrences(of: #",.*$"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            
            let rawParts = stripped.split(whereSeparator: { "/&-".contains($0) }).map(String.init)
            let parts = rawParts
                .map(lettersAndSeparatorsOnly)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            
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
                
                let head = filtered.last
                
                for n in config.maxVariantTokens {
                    guard filtered.count >= n else { continue }
                    for i in 0...(filtered.count - n) {
                        let ngramTokens = Array(filtered[i..<(i + n)])
                        
                        if n == 1, let t = ngramTokens.first {
                            if filtered.count >= 2, config.lowInfoHeads.contains(t) { continue }
                            
                            if filtered.count >= 2 {
                                if t != head, let head, !config.allowModifierSinglesForHeads.contains(head) {
                                    continue
                                }
                            }
                        }
                        
                        variants.insert(ngramTokens.joined(separator: " "))
                    }
                }
                
                if filtered.count <= config.maxVariantTokens.upperBound {
                    let joined = filtered.joined(separator: " ")
                    variants.insert(joined)
                    
                    if let syns = config.synonyms[joined] {
                        for syn in syns {
                            let synClean = lettersAndSeparatorsOnly(syn.lowercased())
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            
                            let synTokens = lemmaTokens(synClean).filter { token in
                                if config.stopWords.contains(token) { return false }
                                if config.prepWords.contains(token) { return false }
                                if config.unitWords.contains(token) { return false }
                                if token.count < 3 && !config.allowShortTokens.contains(token) { return false }
                                return true
                            }
                            
                            if !synTokens.isEmpty {
                                variants.insert(synTokens.joined(separator: " "))
                            }
                        }
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
