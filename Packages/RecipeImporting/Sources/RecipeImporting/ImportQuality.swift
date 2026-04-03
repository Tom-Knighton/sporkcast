//
//  ImportQuality.swift
//  Environment
//
//  Created by Codex on 27/03/2026.
//

import Foundation
import Models

public enum ImportQualityLevel: String, Sendable, Codable, Hashable {
    case high
    case medium
    case low
}

public struct ImportQuality: Sendable, Codable, Hashable {
    public let score: Double
    public let level: ImportQualityLevel
    public let reasons: [String]

    public init(score: Double, level: ImportQualityLevel, reasons: [String]) {
        self.score = score
        self.level = level
        self.reasons = reasons
    }

    public var shouldFallbackToAPI: Bool {
        level == .low || score < 0.55
    }

    public static func evaluate(recipe: Recipe) -> ImportQuality {
        var score = 0.0
        var reasons: [String] = []

        if !recipe.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            score += 0.30
        } else {
            reasons.append("Missing title")
        }

        let ingredientCount = recipe.ingredientSections.flatMap(\.ingredients).count
        if ingredientCount >= 4 {
            score += 0.25
        } else if ingredientCount > 0 {
            score += 0.12
            reasons.append("Very few ingredients")
        } else {
            reasons.append("No ingredients")
        }

        let stepCount = recipe.stepSections.flatMap(\.steps).count
        if stepCount >= 3 {
            score += 0.25
        } else if stepCount > 0 {
            score += 0.12
            reasons.append("Very few steps")
        } else {
            reasons.append("No steps")
        }

        let parsedIngredients = recipe
            .ingredientSections
            .flatMap(\.ingredients)
            .filter { $0.ingredientPart != nil || $0.quantity?.quantity != nil }
            .count

        if ingredientCount > 0 {
            let ratio = Double(parsedIngredients) / Double(ingredientCount)
            if ratio >= 0.6 {
                score += 0.10
            } else {
                reasons.append("Low ingredient parse confidence")
            }
        }

        let parsedStepSignals = recipe
            .stepSections
            .flatMap(\.steps)
            .filter { !$0.timings.isEmpty || !$0.temperatures.isEmpty }
            .count

        if stepCount > 0 {
            let ratio = Double(parsedStepSignals) / Double(stepCount)
            if ratio >= 0.4 {
                score += 0.10
            } else {
                reasons.append("Low timing/temperature extraction")
            }
        }

        score = max(0, min(1, score))

        let level: ImportQualityLevel
        switch score {
        case 0.75...:
            level = .high
        case 0.55..<0.75:
            level = .medium
        default:
            level = .low
        }

        return ImportQuality(score: score, level: level, reasons: reasons)
    }
}
