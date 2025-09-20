//
//  Environment.swift
//  Design
//
//  Created by Tom Knighton on 25/08/2025.
//

import SwiftUI
import API
import Environment

public extension EnvironmentValues {
    
    @Entry var networkClient: any NetworkClient = APIClient(host: "")
}
