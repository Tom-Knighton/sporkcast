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
import UIKit

public struct EditRecipePage: View {
    
    private let recipe: Recipe
    @State private var editingRecipe: Recipe
    
    @State private var totalTime: Duration = .seconds(0)
    @State private var cookTime: Duration = .seconds(0)
    @State private var prepTime: Duration = .seconds(0)
    
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
                }
            }
            .navigationTitle(recipe.title)
        }
        .interactiveDismissDisabled()
        .fontDesign(.rounded)
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
                Text("Cover Image").bold()
                Spacer()
                image()
            }
            .overlay { Color.gray.opacity(0.5) }
            .disabled(true)
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
            ForEach($editingRecipe.ingredientSections, id: \.id) { $section in
                ForEach($section.ingredients, id: \.id) { $ingredient in
                    VStack {
                        IngredientRow(ingredient: $ingredient, tint: Color(hex: editingRecipe.dominantColorHex ?? "#FFFFFF") ?? .white)
                            .listRowSeparator(.visible)
                    }
                }
                .onMove { source, dest in
                    //
                }
            }
        }
        .environment(\.editMode, .constant(.active))
    }
    
    @ViewBuilder
    private func image() -> some View {
        if let url = editingRecipe.image.imageUrl {
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

private struct IngredientRow: View {
    @Binding var ingredient: RecipeIngredient
    @State private var attributed: AttributedString = ""
    let tint: Color
    
    var body: some View {
        HStack {
            ZStack {
                Circle()
                    .frame(width: 25, height: 25)
                    .opacity(0.1)
                
                if let emoji = ingredient.emoji {
                    Text(emoji)
                } else {
                    Image(systemName: "face.dashed")
                }
            }
            .padding(.top, -2)
            .font(.caption)
            
            Text(attributed)
                .opacity(0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: attributed) { _, newValue in
                    let v = String(newValue.characters)
                    ingredient.ingredientText = v
                    self.parseIngredientText(v)
                }
                .onChange(of: ingredient, initial: true) { _, newValue in
                    attributed = IngredientHighlighter.highlight(
                        ingredient: ingredient,
                        font: .body,
                        tint: tint
                    )
                }
                .overlay {
                    TextEditor(text: $attributed)
                        .padding(.horizontal, -4)
                        .padding(.vertical, -10)
                        .scrollDisabled(true)
                }
            
            Image(systemName: "line.3.horizontal")
        }
    }
    
    private func parseIngredientText(_ text: String) {
        let attributed = try? parseIngredient(text, "en")
        self.ingredient.ingredientText = text
        if let attributed {
            ingredient.quantity = .init(quantity: attributed.quantity, quantityText: attributed.quantityText)
            ingredient.unit = .init(unit: attributed.unit, unitText: attributed.unitText)
            ingredient.ingredientPart = attributed.ingredient
            ingredient.extraInformation = attributed.extra
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
                    .init(id: UUID(), sortIndex: 0, instructionText: "Crisp the pancetta in a pan.", timings: [], temperatures: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: []),
                    .init(id: UUID(), sortIndex: 0, instructionText: "Crisp the pancetta in a pan.", timings: [], temperatures: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: []),
                    .init(id: UUID(), sortIndex: 0, instructionText: "Crisp the pancetta in a pan.", timings: [], temperatures: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [])
                ]
            )
        ],
        dominantColorHex: "#00000F",
        homeId: nil
    )
    
    VStack {
        
    }
    .sheet(isPresented: .constant(true)) {
        EditRecipePage(recipe: recipe)
            .environment(AppRouter(initialTab: .recipes))
            .environment(RecipeTimerStore.shared)
    }
}

