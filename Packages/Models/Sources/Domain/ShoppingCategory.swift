//
//  ShoppingCategory.swift
//  ShoppingLists
//
//  Created by Codex on 21/03/2026.
//

import Foundation

public enum ShoppingCategory: String, CaseIterable, Identifiable, Sendable {
    case produce
    case meat
    case seafood
    case dairyAndEggs = "dairy-eggs"
    case bakery
    case pantry
    case frozen
    case snacks
    case beverages
    case household
    case personalCare = "personal-care"
    case unknown

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .produce:
            return "Produce"
        case .meat:
            return "Meat"
        case .seafood:
            return "Seafood"
        case .dairyAndEggs:
            return "Dairy & Eggs"
        case .bakery:
            return "Bakery"
        case .pantry:
            return "Pantry"
        case .frozen:
            return "Frozen"
        case .snacks:
            return "Snacks"
        case .beverages:
            return "Beverages"
        case .household:
            return "Household"
        case .personalCare:
            return "Personal Care"
        case .unknown:
            return "Other"
        }
    }

    public var sortOrder: Int {
        switch self {
        case .produce:
            return 0
        case .meat:
            return 1
        case .seafood:
            return 2
        case .dairyAndEggs:
            return 3
        case .bakery:
            return 4
        case .pantry:
            return 5
        case .frozen:
            return 6
        case .snacks:
            return 7
        case .beverages:
            return 8
        case .household:
            return 9
        case .personalCare:
            return 10
        case .unknown:
            return 11
        }
    }

    public init(categoryIdentifier: String) {
        let normalized = categoryIdentifier
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        switch normalized {
        case "produce", "vegetable", "vegetables", "fruit", "fruits":
            self = .produce
        case "meat", "meats", "protein":
            self = .meat
        case "fish", "seafood":
            self = .seafood
        case "dairy", "dairy-eggs", "dairyandeggs", "eggs":
            self = .dairyAndEggs
        case "bakery", "bread":
            self = .bakery
        case "pantry", "cupboard", "dry-goods", "drygoods":
            self = .pantry
        case "frozen", "freezer":
            self = .frozen
        case "snack", "snacks", "treats":
            self = .snacks
        case "beverage", "beverages", "drinks", "drink":
            self = .beverages
        case "household", "cleaning", "house":
            self = .household
        case "personal", "personal-care", "toiletries", "toiletry":
            self = .personalCare
        default:
            self = .unknown
        }
    }
}
