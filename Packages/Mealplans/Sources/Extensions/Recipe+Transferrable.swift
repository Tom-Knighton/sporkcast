//
//  Recipe+Transferrable.swift
//  Mealplans
//
//  Created by Tom Knighton on 18/11/2025.
//

import SwiftUI
import Models
import UniformTypeIdentifiers

extension Recipe: Transferable {
    
    static public var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .recipe)
    }
}

extension UTType {
    static let recipe = UTType(exportedAs: "online.tomk.sporkcast.recipe")
}
