//
//  Household.swift
//  API
//
//  Created by Tom Knighton on 11/10/2025.
//

import SwiftData
import Foundation

@Model
public final class SDHousehold {
    public var id: UUID = UUID()
    
    public var name: String = ""
    public var createdAt: Date = Date()
    public var updatedAt: Date?
    
    public init(id: UUID = UUID(), name: String) {
        self.id = id
        self.name = name
        self.createdAt = Date()
        self.updatedAt = Date()
    }
}
