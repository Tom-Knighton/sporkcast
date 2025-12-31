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
import Models

public struct RecipeListPage: View {
    
    @Environment(ZoomManager.self) private var zoomManager
    @Environment(\.homeServices) private var homes
    @State private var showDeleteConfirm = false
    @Environment(AppRouter.self) private var router
    @Environment(\.networkClient) private var client
    @State private var importFromUrl: Bool = false
    @State private var importFromUrlText: String = ""
    
    @State private var repository = RecipesRepository()
    
    public init() {}
    
    public var body: some View {
        List(repository.recipes) { recipe in
            @Bindable var zm = zoomManager
            NavigationLink(value: AppDestination.recipe(recipe: recipe)) {
                RecipeCardView(recipe: recipe)
                    .padding(.horizontal)
                    .padding(.vertical, 8)
                    .matchedTransitionSource(id: "zoom-\(recipe.id.uuidString)", in: zm.zoomNamespace)
                    .contextMenu {
                        Button(action: { router.navigateTo(.recipe(recipe: recipe)) }) {
                            Label("Open", systemImage: "hand.point.up")
                        }
                        Divider()
                        Button(role: .destructive) {
                            self.showDeleteConfirm = true
                        } label: { Label("Delete", systemImage: "trash").tint(.red) }
                    }
                    .alert("Delete Recipe", isPresented: $showDeleteConfirm) {
                        Button(role: .cancel) { } label: { Text("Cancel") }
                    } message: {
                        Text("Are you sure you want to delete this recipe? This cannot be undone.")
                    }
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
                    try await repository.deleteAll()
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
                            let entities = await RecipeDTO.entities(from: recipeDTO, for: homes.home?.id)
                            try await repository.saveImportedRecipe(entities)
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
