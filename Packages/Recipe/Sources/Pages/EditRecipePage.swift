//
//  EditRecipePage.swift
//  Recipe
//
//  Created by Tom Knighton on 08/01/2026.
//

import SwiftUI
import Environment
import Design
import Models
import Persistence
import NukeUI
import SQLiteData
import PhotosUI
import UIKit

public struct EditRecipePage: View {
    
    @Dependency(\.defaultDatabase) private var db
    @Environment(\.dismiss) private var dismiss

    private let recipe: Recipe
    @State private var editingRecipe: Recipe
    
    @State private var totalTime: Duration = .seconds(0)
    @State private var cookTime: Duration = .seconds(0)
    @State private var prepTime: Duration = .seconds(0)
    @State private var colour: Color
    @State private var errorMessage: String? = nil
    @State private var showErrorMessage: Bool = false
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    
    @FocusState private var focusedIngredientID: UUID?
    @FocusState private var focusedStepID: UUID?
    
    public init(recipe: Recipe) {
        self.recipe = recipe
        self._editingRecipe = State(wrappedValue: recipe)
        
        if let rTT = recipe.timing.totalTime {
            self._totalTime = .init(wrappedValue: .seconds(60 * rTT))
        }
        if let rCT = recipe.timing.cookTime {
            self._cookTime = .init(wrappedValue: .seconds(60 * rCT))
        }
        if let rPT = recipe.timing.prepTime {
            self._prepTime = .init(wrappedValue: .seconds(60 * rPT))
        }
        
        if let domColour = recipe.dominantColorHex {
            self.colour = Color(hex: domColour) ?? .clear
        } else {
            self.colour = .clear
        }
    }
    
    public var body: some View {
        NavigationStack {
            ZStack {
                Color.layer1.ignoresSafeArea()
                Form {
                    basicDetailsSection()
                    servesSection()
                    timingsSection()
                    ingredientsSection()
                    stepSections()
                }
            }
            .navigationTitle(recipe.title)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(action: { self.dismiss() }) {
                        Image(systemName: "xmark")
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button(action: { Task { await saveRecipe() }}) {
                        Image(systemName: "checkmark")
                    }
                    .buttonStyle(.glassProminent)
                }
            }
        }
        .interactiveDismissDisabled()
        .fontDesign(.rounded)
        .onChange(of: self.errorMessage) { _, newValue in
            self.showErrorMessage = newValue != nil
        }
        .alert("Error", isPresented: $showErrorMessage) {
            Button(role: .confirm) { self.errorMessage = nil }
        } message: {
            Text(errorMessage ?? "Something went wrong")
        }

    }
}

extension EditRecipePage {
    
    @ViewBuilder
    private func basicDetailsSection() -> some View {
        Section {
            LabeledContent {
                TextField("Title", text: $editingRecipe.title)
                    .multilineTextAlignment(.trailing)
            } label: {
                Text("Title").bold()
            }
            
            LabeledContent {
                TextField("(Optional)", text: Binding(
                    get: { editingRecipe.author ?? "" },
                    set: { newValue in
                        editingRecipe.author = newValue.isEmpty ? nil : newValue
                    }
                ))
                .multilineTextAlignment(.trailing)
            } label: {
                Text("Author").bold()
            }
            
            HStack {
                PhotosPicker("Cover Image", selection: $selectedImageItem, matching: .images)
                    .tint(.primary)
                    .bold()
                Spacer()
                image()
            }
            .onChange(of: self.selectedImageItem) { _, newValue in
                if let newValue {
                    Task {
                        if let loaded = try? await newValue.loadTransferable(type: Data.self) {
                            self.selectedImageData = loaded
                        }
                    }
                }
            }
            
            HStack {
                Text("Highlight Colour").bold()
                Spacer()
                ColorPicker("", selection: $colour, supportsOpacity: false)
            }
        }
    }
    
    @ViewBuilder
    private func servesSection() -> some View {
        Section {
            LabeledContent {
                TextField("(Optional)", text: Binding(
                    get: { editingRecipe.serves ?? "" },
                    set: { newValue in
                        editingRecipe.serves = newValue.isEmpty ? nil : newValue
                    }
                ))
                .multilineTextAlignment(.trailing)
            } label: {
                Label {
                    Text("Serves")
                        .bold()
                } icon: {
                    Image(systemName: "person")
                }
            }
        }
    }
    
    @ViewBuilder
    private func timingsSection() -> some View {
        Section {
            DisclosureGroup {
                TimePicker(duration: $totalTime)
            } label: {
                HStack {
                    Label {
                        Text("Total Time")
                            .bold()
                    } icon: {
                        Image(systemName: "clock")
                    }
                    Spacer()
                    
                    if totalTime == .seconds(0) {
                        Text("(Optional)")
                            .foregroundStyle(.separator)
                    } else {
                        Text(totalTime.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }
            }
            
            DisclosureGroup {
                TimePicker(duration: $cookTime)
            } label: {
                HStack {
                    Label {
                        Text("Cook Time")
                            .bold()
                    } icon: {
                        Image(systemName: "clock")
                    }
                    Spacer()
                    
                    if totalTime == .seconds(0) {
                        Text("(Optional)")
                            .foregroundStyle(.separator)
                    } else {
                        Text(cookTime.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }
            }
            
            DisclosureGroup {
                TimePicker(duration: $prepTime)
            } label: {
                HStack {
                    Label {
                        Text("Prep Time")
                            .bold()
                    } icon: {
                        Image(systemName: "clock")
                    }
                    Spacer()
                    
                    if totalTime == .seconds(0) {
                        Text("(Optional)")
                            .foregroundStyle(.separator)
                    } else {
                        Text(prepTime.formatted(.units(allowed: [.hours, .minutes], width: .abbreviated)))
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func ingredientsSection() -> some View {
        Section("Ingredients") {
            ForEach($editingRecipe.ingredientSections) { $section in
                ForEach($section.ingredients) { $ingredient in
                    VStack {
                        IngredientRow(ingredient: $ingredient, tint: Color(hex: editingRecipe.dominantColorHex ?? "#FFFFFF") ?? .white, focusedID: $focusedIngredientID)
                            .listRowSeparator(.visible)
                    }
                }
                .onMove { source, dest in
                    section.ingredients.move(fromOffsets: source, toOffset: dest)
                    for idx in section.ingredients.indices {
                        section.ingredients[idx].sortIndex = idx
                    }
                }
                .onDelete { offsets in
                    section.ingredients.remove(atOffsets: offsets)
                    for idx in section.ingredients.indices {
                        section.ingredients[idx].sortIndex = idx
                    }
                }
                
                HStack {
                    Button(action: {
                        let newID = UUID()
                        section.ingredients.append(.init(id: newID, sortIndex: section.ingredients.count, ingredientText: "", ingredientPart: nil, extraInformation: nil, quantity: nil, unit: nil, emoji: nil, owned: nil))
                        DispatchQueue.main.async { self.focusedIngredientID = newID }
                    }) {
                        Label("Add Ingredient", systemImage: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }
    
    @ViewBuilder
    private func stepSections() -> some View {
        Section("Steps") {
            ForEach($editingRecipe.stepSections) { $stepSection in
                ForEach($stepSection.steps) { $step in
                    StepRow(step: $step, focusedStepID: $focusedStepID, tint: Color(hex: editingRecipe.dominantColorHex ?? "#FFFFFF") ?? .white)
                }
                .onMove { source, dest in
                    stepSection.steps.move(fromOffsets: source, toOffset: dest)
                    for idx in stepSection.steps.indices {
                        stepSection.steps[idx].sortIndex = idx
                    }
                }
                .onDelete { offsets in
                    stepSection.steps.remove(atOffsets: offsets)
                    for idx in stepSection.steps.indices {
                        stepSection.steps[idx].sortIndex = idx
                    }
                }
                
                HStack {
                    Button(action: {
                        let newID = UUID()
                        stepSection.steps.append(.init(id: newID, sortIndex: stepSection.steps.count, instructionText: "", timings: [], temperatures: []))
                        DispatchQueue.main.async { self.focusedStepID = newID }
                    }) {
                        Label("Add Step", systemImage: "plus.circle")
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }
    
    @ViewBuilder
    private func image() -> some View {
        if let item = selectedImageData ?? self.editingRecipe.image.imageThumbnailData, let uiImage = UIImage(data: item) {
            Image(uiImage: uiImage)
                .resizable()
                .aspectRatio(contentMode: .fill)
                .frame(width: 100, height: 100)
                .clipShape(.rect(cornerRadius: 10))
        } else if let url = editingRecipe.image.imageUrl {
            LazyImage(url: URL(string: url)) { state in
                if let img = state.image {
                    img
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .frame(width: 100, height: 100)
                        .clipShape(.rect(cornerRadius: 10))
                } else {
                    Rectangle().opacity(0.1)
                }
            }
        }
        
    }
}

extension EditRecipePage {
    
    private func saveRecipe() async {
        guard editingRecipe.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false else {
            self.errorMessage = "Please enter a title for this recipe."
            return
        }
        
        do {
            let newTiming = RecipeTiming(totalTime: totalTime == .zero ? nil : Double(totalTime.components.seconds) / 60, prepTime: prepTime == .zero ? nil : Double(prepTime.components.seconds) / 60, cookTime: cookTime == .zero ? nil : Double(cookTime.components.seconds) / 60)
            editingRecipe.timing = newTiming
            editingRecipe.dominantColorHex = colour.toHex()
            
            if let image = selectedImageData {
                editingRecipe.image = .init(imageThumbnailData: image, imageUrl: nil)
            }
            
            let (newRecipe, newImage, newIngGroups, newIngs, newStepGroups, newSteps, newStepTimings, newStepTemps, newRatings) = await Recipe.entites(from: editingRecipe)

            try await db.write { [newRecipe, newImage, newIngGroups, newIngs, newStepGroups, newSteps, newStepTimings, newStepTemps, newRatings] db in
                
                try DBRecipe
                    .upsert { newRecipe }
                    .execute(db)
                try DBRecipeImage
                    .upsert { newImage }
                    .execute(db)
                
                // Remove & Reinsert ingredients & temps
                try DBRecipeIngredientGroup
                    .where { $0.recipeId == newRecipe.id }
                    .delete()
                    .execute(db)
                try DBRecipeIngredientGroup
                    .insert { newIngGroups }
                    .execute(db)
                try DBRecipeIngredient
                    .insert { newIngs}
                    .execute(db)
                try DBRecipeStepGroup
                    .where { $0.recipeId == newRecipe.id }
                    .delete()
                    .execute(db)
                try DBRecipeStepGroup
                    .insert { newStepGroups }
                    .execute(db)
                try DBRecipeStep
                    .insert { newSteps}
                    .execute(db)
                try DBRecipeStepTiming
                    .insert { newStepTimings }
                    .execute(db)
                try DBRecipeStepTemperature
                    .insert { newStepTemps }
                    .execute(db)
                
                // Ratings
                try DBRecipeRating
                    .where { $0.recipeId == newRecipe.id }
                    .delete()
                    .execute(db)
                try DBRecipeRating
                    .insert { newRatings }
                    .execute(db)
            }
            
            self.dismiss()
        } catch {
            self.errorMessage = "Failed to save recipe."
            return
        }
    }
}

#Preview {
    
    let _ = PreviewSupport.preparePreviewDatabase()
    
    let recipe = Recipe(
        id: UUID(),
        title: "Preview Carbonara",
        description: "Creamy pasta with crispy pancetta and pecorino.",
        summarisedTip: "Users tend to recommend adding less salt than recommended - but comment that you may need to add spices to taste as it's a bit bland. Overall positive reviews.",
        author: nil,
        sourceUrl: "https://example.com/carbonara",
        image: .init(imageThumbnailData: nil, imageUrl: "https://ichef.bbci.co.uk/food/ic/food_16x9_1600/recipes/sausage_and_mash_pie_94920_16x9.jpg"),
        timing: .init(totalTime: 30, prepTime: 10, cookTime: 20),
        serves: "4",
        ratingInfo: .init(overallRating: 4.5, totalRatings: 3, summarisedRating: "Rich and comforting", ratings: [
            .init(id: UUID(), rating: 5, comment: "A bit salty but overall very nice!"),
            .init(id: UUID(), rating: 5, comment: "The perfect authentic carbonarra"),
            .init(id: UUID(), rating: 1, comment: "Missing too many ingredients!"),
        ]),
        dateAdded: .now,
        dateModified: .now,
        ingredientSections: [
            .init(
                id: UUID(),
                title: "Main Ingredients",
                sortIndex: 0,
                ingredients: [
                    .init(id: UUID(), sortIndex: 0, ingredientText: "200g pancetta chopped into tiny tiny little pieces and make sure it's not too fatty!", ingredientPart: "pancetta", extraInformation: nil, quantity: .init(quantity: 200, quantityText: "200"), unit: .init(unit: "g", unitText: "g"), emoji: "🥓", owned: false),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "3 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "4 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "5 large eggs", ingredientPart: "eggs", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                    .init(id: UUID(), sortIndex: 1, ingredientText: "2 chicken breasts chopped into bite-sized pieces", ingredientPart: "chicken breasts", extraInformation: nil, quantity: .init(quantity: 3, quantityText: "3"), unit: nil, emoji: "🥚", owned: true),
                ]
            )
        ],
        stepSections: [
            .init(
                id: UUID(),
                sortIndex: 0,
                title: "Steps",
                steps: [
                    .init(id: UUID(), sortIndex: 0, instructionText: "Turn the oven to 180°C and pre-heat for 20 minutes", timings: [.init(id: UUID(), timeInSeconds: 1200, timeText: "20", timeUnitText: "minutes")], temperatures: [.init(id: UUID(), temperature: 180, temperatureText: "180°C", temperatureUnitText: "C")]),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: []),
                    .init(id: UUID(), sortIndex: 2, instructionText: "Do a third thing", timings: [], temperatures: []),
                    .init(id: UUID(), sortIndex: 3, instructionText: "And a fourth", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: []),
                    .init(id: UUID(), sortIndex: 4, instructionText: "And a fifth", timings: [], temperatures: []),
                    .init(id: UUID(), sortIndex: 5, instructionText: "And a sixth!", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [])
                ]
            )
        ],
        dominantColorHex: "#FF0000",
        homeId: nil
    )
    
    VStack {
        
    }
    .sheet(isPresented: .constant(true)) {
        EditRecipePage(recipe: recipe)
            .environment(AppRouter(initialTab: .recipes))
            .environment(RecipeTimerStore.shared)
            .environment(AlertManager())
    }
}

