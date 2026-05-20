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
    public var enableWebSelectionImport: Bool = false
    public var enableOcrImport: Bool = false
    
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
        case enableWebSelectionImport
        case enableOcrImport
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
        enableWebSelectionImport = try container.decodeIfPresent(Bool.self, forKey: .enableWebSelectionImport) ?? false
        enableOcrImport = try container.decodeIfPresent(Bool.self, forKey: .enableOcrImport) ?? false
    }
}
