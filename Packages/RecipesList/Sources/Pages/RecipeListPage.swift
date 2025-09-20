//
//  RecipeListPage.swift
//  RecipesList
//
//  Created by Tom Knighton on 19/09/2025.
//

import SwiftUI
import Environment
import UIKit
import SwiftData
import Design
import API

public struct RecipeListPage: View {
    
    @Environment(ZoomManager.self) private var zoomManager
    @Environment(\.modelContext) private var context
    @Query(sort: \Recipe.dateModified, order: .reverse) private var recipes: [Recipe]
    @Environment(\.networkClient) private var client
    @State private var importFromUrl: Bool = false
    @State private var importFromUrlText: String = ""
    
    public init() {}
    
    public var body: some View {
        List(recipes) { recipe in
            @Bindable var zm = zoomManager
            NavigationLink(value: AppDestination.recipe(id: recipe.id)) {
                RecipeCardView(recipe: recipe)
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
                    try? context.delete(model: Recipe.self)
                    try? context.save()
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
                            let recipe = await Recipe(from: recipeDTO)
                            context.insert(recipe)
                            try context.save()
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

#Preview {
    
    let config = ModelConfiguration(isStoredInMemoryOnly: true)
    let container = try! ModelContainer(for: Recipe.self, configurations: config)

    NavigationStack {
        RecipeListPage()
    }
    .modelContainer(container)
    .task {
        let recipe = await Recipe(from: RecipeDTOMockBuilder().build())
        container.mainContext.insert(recipe)
    }
}
