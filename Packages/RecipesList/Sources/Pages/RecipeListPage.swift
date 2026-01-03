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
import Persistence

public struct RecipeListPage: View {
    
    @Environment(ZoomManager.self) private var zoomManager
    @Environment(\.homeServices) private var homes
    @Environment(AppRouter.self) private var router
    @Environment(\.networkClient) private var client
    @State private var importFromUrl: Bool = false
    @State private var importFromUrlText: String = ""
    
    @State private var repository = RecipesRepository()
    
    @State private var showDeleteConfirmId: UUID? = nil
    private var alertIsPresented: Binding<Bool> {
        Binding(
            get: { showDeleteConfirmId != nil },
            set: { isPresented in
                if !isPresented {
                    showDeleteConfirmId = nil
                }
            }
        )
    }
    
    public init() {}
    
    public var body: some View {
        ZStack {
            @Bindable var zm = zoomManager
            Color.layer1.ignoresSafeArea()
            ScrollView {
                LazyVStack {
                    ForEach(repository.recipes) { recipe in
                        NavigationLink(value: AppDestination.recipe(recipe: recipe)) {
                            RecipeCardView(recipe: recipe)
                                .matchedTransitionSource(id: "zoom-\(recipe.id.uuidString)", in: zm.zoomNamespace)
                                .contentShape(.rect(cornerRadius: 20))
                                .containerShape(.rect(cornerRadius: 20))
                                .contextMenu {
                                    Button(action: { router.navigateTo(.recipe(recipe: recipe)) }) {
                                        Label("Open", systemImage: "hand.point.up")
                                    }
                                    Divider()
                                    
                                    Button(role: .destructive) {
                                        self.showDeleteConfirmId = recipe.id
                                    } label: { Label("Delete", systemImage: "trash").tint(.red) }
                                }
                                .confirmationDialog(
                                    "Are you sure you want to delete this recipe? This cannot be undone.",
                                    isPresented: alertIsPresented,
                                    titleVisibility: .visible,
                                    presenting: showDeleteConfirmId,
                                ) { id in
                                    Button(role: .destructive) {
                                        Task {
                                            await deleteRecipe(id: id)
                                        }
                                    } label: { Text("Delete") }
                                    Button(role: .cancel) { } label: { Text("Cancel") }
                                }
                        }
                        .buttonStyle(.plain)
                        .navigationLinkIndicatorVisibility(.hidden)
                    }
                }
            }
            .contentMargins(.horizontal, 16, for: .scrollContent)
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
}

extension RecipeListPage {
    
    private func deleteRecipe(id: UUID) async {
        do {
            try await repository.delete(id)
        } catch {
            print(error)
        }
    }
}

#Preview {
    @Previewable @Namespace var zm
    let today = Calendar(identifier: .iso8601).startOfDay(for: .now)
    let recipeId = UUID()
    
    let _ = PreviewSupport.preparePreviewDatabase(seed: { db in
        let now = Date()
        let recipe = DBRecipe(
            id: recipeId,
            title: "Preview Stir Fry",
            description: "Colourful veggies with noodles and peanut sauce.",
            author: "Preview Kitchen",
            sourceUrl: "https://example.com/stirfry",
            dominantColorHex: nil,
            minutesToPrepare: 10,
            minutesToCook: 15,
            totalMins: 25,
            serves: "2",
            overallRating: 4.7,
            totalRatings: 12,
            summarisedRating: "Quick comfort food",
            summarisedSuggestion: nil,
            dateAdded: now,
            dateModified: now,
            homeId: nil
        )
        
        do {
            try db.write { db in
                try DBRecipe.insert { recipe }.execute(db)
                try DBRecipeImage.insert { DBRecipeImage(recipeId: recipeId, imageSourceUrl: "https://www.allrecipes.com/thmb/xcOdImFBdut09lTsPnOxIjnv-2E=/0x512/filters:no_upscale():max_bytes(150000):strip_icc()/228823-quick-beef-stir-fry-DDMFS-4x3-1f79b031d3134f02ac27d79e967dfef5.jpg", imageData: nil) }.execute(db)
            }
        } catch {
            print("Preview DB setup failed: \(error)")
        }
    })
    
    NavigationStack {
        RecipeListPage()
    }
    .environment(AppRouter(initialTab: .mealplan))
    .environment(ZoomManager(zm))
    .environment(\.homeServices, MockHouseholdService())
}
