//
//  AppSettings.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import Foundation

public struct AppSettings: Codable, Equatable, Sendable {
    
    public var version: Int = 1
    public var preferredLaunchTab: AppTab = .recipes
    public var theme: Theme = .system
    public var remindersSyncEnabled: Bool = false
    public var remindersCalendarIdentifier: String?
    public var remindersNeedsGroceriesSetupPrompt: Bool = false
    public var mealplanCalendarSyncEnabled: Bool = false
    public var mealplanCalendarIdentifier: String?
    public var enableWebSelectionImport: Bool = false
    public var enableOcrImport: Bool = false
    public var showMealplanWeather: Bool = false
    public var weatherLocationOverrideLatitude: Double?
    public var weatherLocationOverrideLongitude: Double?
    public var showMealplanPage: Bool = true
    public var greyOutPastMealplanDays: Bool = true
    public var mealplanWeekStartWeekday: Int = 2
    public var showDiscoveryPage: Bool = true
    public var showGroceriesPage: Bool = true
    public var showIngredientEmojis: Bool = true
    
    public enum Theme: String, Codable, CaseIterable, Identifiable, Sendable {
        public var id: String { String(describing: self) }
        case system, light, dark }
    
    public static let `default` = AppSettings()

    enum CodingKeys: String, CodingKey {
        case version
        case preferredLaunchTab
        case theme
        case remindersSyncEnabled
        case remindersCalendarIdentifier
        case remindersNeedsGroceriesSetupPrompt
        case mealplanCalendarSyncEnabled
        case mealplanCalendarIdentifier
        case enableWebSelectionImport
        case enableOcrImport
        case showMealplanWeather
        case weatherLocationOverrideLatitude
        case weatherLocationOverrideLongitude
        case showMealplanPage
        case greyOutPastMealplanDays
        case mealplanWeekStartWeekday
        case showDiscoveryPage
        case showGroceriesPage
        case showIngredientEmojis
    }

    public init() {}

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        version = try container.decodeIfPresent(Int.self, forKey: .version) ?? 1
        preferredLaunchTab = try container.decodeIfPresent(AppTab.self, forKey: .preferredLaunchTab) ?? .recipes
        theme = try container.decodeIfPresent(Theme.self, forKey: .theme) ?? .system
        remindersSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .remindersSyncEnabled) ?? false
        remindersCalendarIdentifier = try container.decodeIfPresent(String.self, forKey: .remindersCalendarIdentifier)
        remindersNeedsGroceriesSetupPrompt = try container.decodeIfPresent(Bool.self, forKey: .remindersNeedsGroceriesSetupPrompt) ?? false
        mealplanCalendarSyncEnabled = try container.decodeIfPresent(Bool.self, forKey: .mealplanCalendarSyncEnabled) ?? false
        mealplanCalendarIdentifier = try container.decodeIfPresent(String.self, forKey: .mealplanCalendarIdentifier)
        enableWebSelectionImport = try container.decodeIfPresent(Bool.self, forKey: .enableWebSelectionImport) ?? false
        enableOcrImport = try container.decodeIfPresent(Bool.self, forKey: .enableOcrImport) ?? false
        showMealplanWeather = try container.decodeIfPresent(Bool.self, forKey: .showMealplanWeather) ?? false
        weatherLocationOverrideLatitude = try container.decodeIfPresent(Double.self, forKey: .weatherLocationOverrideLatitude)
        weatherLocationOverrideLongitude = try container.decodeIfPresent(Double.self, forKey: .weatherLocationOverrideLongitude)
        showMealplanPage = try container.decodeIfPresent(Bool.self, forKey: .showMealplanPage) ?? true
        greyOutPastMealplanDays = try container.decodeIfPresent(Bool.self, forKey: .greyOutPastMealplanDays) ?? true
        mealplanWeekStartWeekday = try container.decodeIfPresent(Int.self, forKey: .mealplanWeekStartWeekday) ?? 2
        showDiscoveryPage = try container.decodeIfPresent(Bool.self, forKey: .showDiscoveryPage) ?? true
        showGroceriesPage = try container.decodeIfPresent(Bool.self, forKey: .showGroceriesPage) ?? true
        showIngredientEmojis = try container.decodeIfPresent(Bool.self, forKey: .showIngredientEmojis) ?? true
    }
}
