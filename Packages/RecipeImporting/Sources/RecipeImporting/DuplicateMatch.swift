//
//  DuplicateMatch.swift
//  Environment
//
//  Created by Tom Knighton on 27/03/2026.
//

import Foundation
import Models

public struct DuplicateMatch: Sendable, Hashable, Identifiable {
    public let id: UUID
    public let candidateID: UUID
    public let existingRecipeID: UUID
    public let existingTitle: String
    public let confidence: Double
    public let reason: String

    public init(
        id: UUID = UUID(),
        candidateID: UUID,
        existingRecipeID: UUID,
        existingTitle: String,
        confidence: Double,
        reason: String
    ) {
        self.id = id
        self.candidateID = candidateID
        self.existingRecipeID = existingRecipeID
        self.existingTitle = existingTitle
        self.confidence = confidence
        self.reason = reason
    }
}

public enum DuplicateResolution: String, Sendable, Codable, Hashable, CaseIterable, Identifiable {
    case keepBoth
    case skip
    case replace

    public var id: String { rawValue }

    public var title: String {
        switch self {
        case .keepBoth:
            return "Keep Both"
        case .skip:
            return "Skip"
        case .replace:
            return "Replace Existing"
        }
    }
}

public struct DuplicateResolutionDecision: Sendable, Hashable {
    public let candidateID: UUID
    public let resolution: DuplicateResolution
    public let existingRecipeID: UUID?

    public init(candidateID: UUID, resolution: DuplicateResolution, existingRecipeID: UUID?) {
        self.candidateID = candidateID
        self.resolution = resolution
        self.existingRecipeID = existingRecipeID
    }
}

public extension Recipe {
    func duplicateSimilarity(with other: Recipe) -> (score: Double, reason: String) {
        RecipeDuplicateSummary(recipe: self).duplicateSimilarity(with: RecipeDuplicateSummary(recipe: other))
    }
}

public extension RecipeDuplicateSummary {
    func duplicateSimilarity(with other: RecipeDuplicateSummary) -> (score: Double, reason: String) {
        if let source = Self.sourceKey(sourceURL), source == Self.sourceKey(other.sourceURL) {
            return (1, "Matching source URL")
        }
        let lhsTitle = Self.titleKey(title)
        let rhsTitle = Self.titleKey(other.title)
        var score = 0.0
        var reasons: [String] = []
        if !lhsTitle.isEmpty && lhsTitle == rhsTitle {
            score += 0.70
            reasons.append("Matching title")
        }
        let lhsIngredients = Set(ingredientNames.map(Self.titleKey).filter { !$0.isEmpty })
        let rhsIngredients = Set(other.ingredientNames.map(Self.titleKey).filter { !$0.isEmpty })
        if !lhsIngredients.isEmpty && !rhsIngredients.isEmpty {
            let ratio = Double(lhsIngredients.intersection(rhsIngredients).count) / Double(max(lhsIngredients.count, rhsIngredients.count))
            if ratio >= 0.5 {
                score += 0.30 * ratio
                reasons.append("Ingredient overlap \(Int(ratio * 100))%")
            }
        }
        return (min(1, score), reasons.joined(separator: ", "))
    }
}
