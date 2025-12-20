//
//  Environment.swift
//  Design
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API
import AlarmKit
import Environment

public extension EnvironmentValues {
    
    @Entry var networkClient: any NetworkClient = APIClient(host: "")
    @Entry var appSettings: SettingsStore = SettingsStore()
    @Entry var homeServices: any HouseholdServiceProtocol = HouseholdService.shared
    @Entry var cloudKit: any CloudKitGateProtocol = CloudKitGate()
}
