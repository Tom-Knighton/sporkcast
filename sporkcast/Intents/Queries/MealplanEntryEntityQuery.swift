//
//  MealplanEntryEntityQuery.swift
//  sporkcast
//
//  Created by Tom Knighton on 16/06/2026.
//

import AppIntents
import Environment
import CoreSpotlight

public struct PlannedMealQuery: EnumerableEntityQuery, EntityStringQuery {

    @MainActor
    private var repository = MealplanRepository()
    
    public init() {}
    
    public func entities(for identifiers: [PlannedMealEntity.ID]) async throws -> [PlannedMealEntity] {
        let entries = try await repository.getById(identifiers)
        return entries.compactMap {
            PlannedMealEntity(mealplanEntry: $0)
        }
    }
    
    public func suggestedEntities() async throws -> [PlannedMealEntity] {
        let thisWeek = MealPlanPeriod.thisWeek
        let interval = thisWeek.dateInterval()
        let entries = try await repository.entries(startDate: interval.start, endDate: interval.end)
        return entries.compactMap {
            PlannedMealEntity(mealplanEntry: $0)
        }
    }
    
    public func entities(matching string: String) async throws -> [PlannedMealEntity] {
        let entities = try await repository.getByLookup(string)
        
        return entities.compactMap { PlannedMealEntity(mealplanEntry: $0) }
    }
    
    public func allEntities() async throws -> [PlannedMealEntity] {
        let entities = try await repository.getAllEntries()
        
        return entities.compactMap { PlannedMealEntity(mealplanEntry: $0) }
    }
}

@available(anyAppleOS 27.0, *)
extension PlannedMealQuery: IndexedEntityQuery {
    public func reindexEntities(for identifiers: [PlannedMealEntity.ID], indexDescription: CSSearchableIndexDescription) async throws {
        let entities = try await entities(for: identifiers)
        try await CSSearchableIndex.default().indexAppEntities(entities)
    }

    public func reindexAllEntities(indexDescription: CSSearchableIndexDescription) async throws {
        let entities = try await allEntities()
        try await CSSearchableIndex.default().indexAppEntities(entities)
    }
}
