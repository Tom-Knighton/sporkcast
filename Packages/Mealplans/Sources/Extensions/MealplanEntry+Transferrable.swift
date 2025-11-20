//
//  Recipe+Transferrable.swift
//  Mealplans
//
//  Created by Tom Knighton on 18/11/2025.
//

import SwiftUI
import Models
import UniformTypeIdentifiers

extension MealplanEntry: Transferable {
    
    static public var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .mealplanEntry)
    }
}

extension UTType {
    static let mealplanEntry = UTType(exportedAs: "online.tomk.sporkcast.mealplanentry")
}
