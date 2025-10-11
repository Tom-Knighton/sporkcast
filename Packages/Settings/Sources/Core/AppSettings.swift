//
//  AppSettings.swift
//  Settings
//
//  Created by Tom Knighton on 11/10/2025.
//

import Foundation

public enum SettingsKey: String, CaseIterable {
    case theme
}

public extension UserDefaults {
    nonisolated(unsafe) static let settingsGroup: UserDefaults = {
        guard let d = UserDefaults(suiteName: "app.settings.v1") else {
            fatalError("Missing app group")
        }
        return d
    }()
}
