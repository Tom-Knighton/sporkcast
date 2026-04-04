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
        let lhsTitle = title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let rhsTitle = other.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        var score = 0.0
        var reasons: [String] = []

        if !lhsTitle.isEmpty && lhsTitle == rhsTitle {
            score += 0.70
            reasons.append("Matching title")
        }

        let lhsIngredients = Set(ingredientSections.flatMap(\.ingredients).compactMap {
            ($0.ingredientPart ?? $0.ingredientText)
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })

        let rhsIngredients = Set(other.ingredientSections.flatMap(\.ingredients).compactMap {
            ($0.ingredientPart ?? $0.ingredientText)
                .lowercased()
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }.filter { !$0.isEmpty })

        if !lhsIngredients.isEmpty && !rhsIngredients.isEmpty {
            let overlap = lhsIngredients.intersection(rhsIngredients).count
            let maxCount = max(lhsIngredients.count, rhsIngredients.count)
            let overlapRatio = Double(overlap) / Double(maxCount)
            if overlapRatio >= 0.5 {
                score += 0.30 * overlapRatio
                reasons.append("Ingredient overlap \(Int(overlapRatio * 100))%")
            }
        }

        return (min(1.0, score), reasons.joined(separator: ", "))
    }
}
