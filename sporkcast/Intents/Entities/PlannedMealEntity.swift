//
//  MealplanEntryEntity.swift
//  sporkcast
//
//  Created by Tom Knighton on 16/06/2026.
//

import Foundation
import AppIntents
import CoreSpotlight
import Models

=public struct PlannedMealEntity: IndexedEntity, Identifiable, Sendable {
    
    public static let typeDisplayRepresentation = TypeDisplayRepresentation(name: "Planned Meal")
    public static let defaultQuery = PlannedMealQuery()
    
    public let id: UUID
    
    @Property(title: "Recipe", indexingKey: \.title)
    public var recipeName: String
    
    @Property(title: "Date")
    public var date: Date
    
    @Property(title: "ImageUrl")
    public var imageUrl: URL?
    
    public var displayRepresentation: DisplayRepresentation {
        let dateText = date.formatted(date: .abbreviated, time: .omitted)

        let synonyms: [LocalizedStringResource] = ["mealplan", "meal plan", "dinner", "eating", "\(recipeName)", "\(dateText)"]
        if let imageUrl {
            return DisplayRepresentation(title: "\(recipeName)", subtitle: "\(dateText)", image: .init(url: imageUrl), synonyms: synonyms)
        } else {
            return DisplayRepresentation(title: "\(recipeName)", subtitle: "\(dateText))", synonyms: synonyms)
        }
    }

    public var attributeSet: CSSearchableItemAttributeSet {
        let attributeSet = defaultAttributeSet
        let dateText = date.formatted(date: .abbreviated, time: .omitted)

        attributeSet.contentURL = URL(string: "sporkcast://mealplan?id=\(id.uuidString)")
        
        attributeSet.keywords = [
            "meal plan",
            "mealplan",
            "planned meal",
            "dinner",
            "eating",
            recipeName,
            dateText
        ]
        
        attributeSet.alternateNames = [
            "\(recipeName) meal",
            "\(recipeName) dinner"
        ]
        
        attributeSet.contentDescription = "Planned for \(dateText)"

        return attributeSet
    }
    

    public init(mealplanEntry: MealplanEntry) {
        self.id = mealplanEntry.id
        self.recipeName = mealplanEntry.recipe?.title ?? mealplanEntry.note ?? "No Recipe"
        self.date = mealplanEntry.date
        self.imageUrl = URL(string: mealplanEntry.recipe?.image.imageUrl ?? "")
    }
}
