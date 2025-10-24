//
//  Home.swift
//  Models
//
//  Created by Tom Knighton on 24/10/2025.
//

import Foundation
import Persistence

public struct Home: Identifiable, Hashable {
    public let id: UUID
    public var name: String
    
    public init(id: UUID, name: String) {
        self.id = id
        self.name = name
    }
    
    public init(from: DBHome) {
        self.id = from.id
        self.name = from.name
    }
}
