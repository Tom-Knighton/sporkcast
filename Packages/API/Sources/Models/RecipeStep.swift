//
//  RecipeStep.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeStep: Codable {
    public let step: String
    public let times: [RecipeStepTime]
    public let temperatures: [RecipeStepTemperature]
    
    public init(step: String, times: [RecipeStepTime], temperatures: [RecipeStepTemperature]) {
        self.step = step
        self.times = times
        self.temperatures = temperatures
    }
}

public struct RecipeStepTime: Codable {
    public let timeInSeconds: Double
    public let timeText: String
    public let timeUnitText: String
    
    public init(timeInSeconds: Double, timeText: String, timeUnitText: String) {
        self.timeInSeconds = timeInSeconds
        self.timeText = timeText
        self.timeUnitText = timeUnitText
    }
}

public struct RecipeStepTemperature: Codable {
    public let temperature: Double
    public let temperatureUnitText: String
    public let temperatureText: String
    
    public init(temperature: Double, temperatureUnitText: String, temperatureText: String) {
        self.temperature = temperature
        self.temperatureUnitText = temperatureUnitText
        self.temperatureText = temperatureText
    }
}
