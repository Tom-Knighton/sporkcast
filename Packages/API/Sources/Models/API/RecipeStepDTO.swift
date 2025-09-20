//
//  RecipeStep.swift
//  API
//
//  Created by Tom Knighton on 25/08/2025.
//

public struct RecipeStepDTO: Codable {
    public let step: String
    public let times: [RecipeStepTimeDTO]
    public let temperatures: [RecipeStepTemperatureDTO]
    
    init(step: String, times: [RecipeStepTimeDTO], temperatures: [RecipeStepTemperatureDTO]) {
        self.step = step
        self.times = times
        self.temperatures = temperatures
    }
}

public struct RecipeStepTimeDTO: Codable {
    public let timeInSeconds: Double
    public let timeText: String
    public let timeUnitText: String
    
    init(timeInSeconds: Double, timeText: String, timeUnitText: String) {
        self.timeInSeconds = timeInSeconds
        self.timeText = timeText
        self.timeUnitText = timeUnitText
    }
}

public struct RecipeStepTemperatureDTO: Codable {
    public let temperature: Double
    public let temperatureUnitText: String
    public let temperatureText: String
    
    init(temperature: Double, temperatureUnitText: String, temperatureText: String) {
        self.temperature = temperature
        self.temperatureUnitText = temperatureUnitText
        self.temperatureText = temperatureText
    }
}
