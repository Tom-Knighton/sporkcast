//
//  V1Models.swift
//  API
//
//  Created by Tom Knighton on 20/09/2025.
//

import SwiftData

public struct V1Models {
    
    public static let sharedContainer: ModelContainer? = {
        let schema = Schema([Recipe.self, RecipeIngredient.self, RecipeStepSection.self, RecipeStep.self, RecipeStepTiming.self, RecipeStepTemp.self, Household.self])
        let config = ModelConfiguration(
            schema: schema,
            isStoredInMemoryOnly: false,
            cloudKitDatabase: .private("iCloud.online.tomk.sporkcast")
        )
        
        return try! ModelContainer(for: schema, configurations: config)
    }()
}
