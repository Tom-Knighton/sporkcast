//
//  RecipeStep.swift
//  API
//
//  Created by Tom Knighton on 21/10/2025.
//

import Foundation

public struct RecipeStepSection: Identifiable, Hashable, Sendable, Codable {
    
    public let id: UUID
    
    /// Where this step section should be displayed in the recipe
    public let sortIndex: Int
    
    /// The title of the step section, should only be shown when there's > 1 section. Will be 'For the sauce:' etc.
    public var title: String
    
    public var steps: [RecipeStep]
    
    public init(id: UUID, sortIndex: Int, title: String, steps: [RecipeStep]) {
        self.id = id
        self.sortIndex = sortIndex
        self.title = title
        self.steps = steps
    }
}

public struct RecipeStep: Identifiable, Hashable, Sendable, Codable {
    
    public let id: UUID
    
    /// Where this step should be ordered within the section
    public let sortIndex: Int
    
    /// The actual text of the step i.e. 'Stir the sauce for 20 minutes'
    public let instructionText: String
    
    /// Any identified timings in the recipe step
    public let timings: [RecipeStepTiming]
    
    /// Any identified temperatures in the recipe step
    public let temperatures: [RecipeStepTemperature]
    
    public init(id: UUID, sortIndex: Int, instructionText: String, timings: [RecipeStepTiming], temperatures: [RecipeStepTemperature]) {
        self.id = id
        self.sortIndex = sortIndex
        self.instructionText = instructionText
        self.timings = timings
        self.temperatures = temperatures
    }
}

public struct RecipeStepTiming: Identifiable, Hashable, Sendable, Codable {
    
    public let id: UUID
    
    /// The time of this 'timing' in seconds
    public let timeInSeconds: Double
    
    /// The text of the time itself from the recipe's original text i.e. '20'
    public let timeText: String
    
    /// The text of the time unit from the recipe's original text i.e. 'mins' 'minutes', 'seconds'
    public let timeUnitText: String
    
    public init(id: UUID, timeInSeconds: Double, timeText: String, timeUnitText: String) {
        self.id = id
        self.timeInSeconds = timeInSeconds
        self.timeText = timeText
        self.timeUnitText = timeUnitText
    }
}

public struct RecipeStepTemperature: Identifiable, Hashable, Sendable, Codable {
    
    public let id: UUID
    
    /// The actual temperature i.e. '200'
    public let temperature: Double
    
    /// The text of the temperature itself from the recipe's original text i.e. '200'
    public let temperatureText: String
    
    /// The text of the temperature unit from the recipe's original text i.e. 'c' 'celsius', 'f'
    public let temperatureUnitText: String
    
    public init(id: UUID, temperature: Double, temperatureText: String, temperatureUnitText: String) {
        self.id = id
        self.temperature = temperature
        self.temperatureText = temperatureText
        self.temperatureUnitText = temperatureUnitText
    }
}
