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
    
    public enum Theme: String, Codable, CaseIterable, Identifiable, Sendable {
        public var id: String { String(describing: self) }
        case system, light, dark }
    
    public static let `default` = AppSettings()
}
