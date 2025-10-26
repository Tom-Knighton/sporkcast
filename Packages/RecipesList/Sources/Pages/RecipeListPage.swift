//
//  RecipeListPage.swift
//  RecipesList
//
//  Created by Tom Knighton on 19/09/2025.
//

import SwiftUI
import Environment
import UIKit
import Design
import API
import Persistence
import SQLiteData
import Models

public struct RecipeListPage: View {
    
    @Environment(ZoomManager.self) private var zoomManager
    @Environment(\.homeServices) private var homes

    @Environment(\.networkClient) private var client
    @State private var importFromUrl: Bool = false
    @State private var importFromUrlText: String = ""
    
    @Dependency(\.defaultDatabase) var database
    @FetchAll(DBRecipe.full) private var recipes: [FullDBRecipe]
    
    public init() {}
    
    public var body: some View {
        List(recipes) { recipe in
            let model = recipe.toDomainModel()
            @Bindable var zm = zoomManager
            NavigationLink(value: AppDestination.recipe(recipe: model)) {
                RecipeCardView(recipe: model)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .matchedTransitionSource(id: "zoom-\(recipe.id.uuidString)", in: zm.zoomNamespace)
            }
            .navigationLinkIndicatorVisibility(.hidden)
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets())
            .listRowBackground(Color.clear)
            
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color.layer1)
        .navigationTitle("Recipes")
        .toolbar {
            ToolbarItem {
                Menu {
                    Section("Import Recipe") {
                        Button(action: { self.importFromUrl = true }) {
                            Label("From web", systemImage: "link")
                        }
                    }
                } label: {
                    Image(systemName: "plus")
                }
                
            }
            ToolbarSpacer(.fixed)
            ToolbarItem {
                Button(action: { Task {
                    try await database.write { db in
                        try DBRecipe.delete().execute(db)
                    }
                }}) {
                    Image(systemName: "xmark")
                }
                .tint(.red)
            }
        }
        .alert("Import Recipe", isPresented: $importFromUrl) {
            TextField("Enter Recipe URL", text: $importFromUrlText)
                .textContentType(.URL)
            Button("Import") {
                Task {
                    do {
                        let recipeDTO: RecipeDTO? = try await client.post(Recipes.uploadFromUrl(url: importFromUrlText))
                        
                        if let recipeDTO {
                            let (recipe, image, ingGroups, ings, stepGroups, steps, times, temps) = await RecipeDTO.entities(from: recipeDTO, for: homes.home?.id)
                            
                            try await database.write { db in
                                try DBRecipe.insert { recipe }.execute(db)
                                try DBRecipeImage.insert { image }.execute(db)
                                try DBRecipeIngredientGroup.insert { ingGroups }.execute(db)
                                try DBRecipeIngredient.insert { ings }.execute(db)
                                try DBRecipeStepGroup.insert { stepGroups }.execute(db)
                                try DBRecipeStep.insert { steps }.execute(db)
                                try DBRecipeStepTiming.insert { times }.execute(db)
                                try DBRecipeStepTemperature.insert { temps }.execute(db)
                            }
                            print("saved")
                        } else {
                            print("Failed parsing recipe")
                        }
                    } catch {
                        print(error)
                    }
                    
                }
            }
            .buttonStyle(.borderedProminent)
            Button("Cancel") {
                
            }
        } message: {
            Text("Enter or paste the url to the recipe from the internet")
        }
        
    }
}

