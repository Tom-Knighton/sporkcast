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

public struct EditRecipePage: View {
    
    private let recipe: Recipe
    @State private var editingRecipe: Recipe
    
    @State private var totalTime: Duration = .seconds(0)
    @State private var cookTime: Duration = .seconds(0)
    @State private var prepTime: Duration = .seconds(0)
    
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

private struct StepRow: View {
    @Binding var step: RecipeStep
    let focusedStepID: FocusState<UUID?>.Binding
    let tint: Color

    @State private var attributed: AttributedString = ""
    
    var body: some View {
        HStack {
            Text(attributed)
                .opacity(0)
                .frame(maxWidth: .infinity, alignment: .leading)
                .onChange(of: attributed) { _, newValue in
                    let v = String(newValue.characters)
                    step.instructionText = v
                    self.parseInstructionText(v)
                }
                .onChange(of: step, initial: true) { _, newValue in
                    attributed = RecipeStepHighlighter.highlight(
                        step: step,
                        font: .body,
                        tint: .primary
                    )
                }
                .overlay {
                    TextEditor(text: $attributed)
                        .padding(.horizontal, -4)
                        .padding(.vertical, -10)
                        .scrollDisabled(true)
                        .focused(focusedStepID, equals: step.id)
                }
            
            Image(systemName: "line.3.horizontal")
        }
        
    }
    
    private func parseInstructionText(_ text: String) {
        let attributed = try? parseInstruction(text, "en")
        self.step.instructionText = text
        if let attributed {
            if attributed.temperature != 0 {
                step.temperatures = [.init(id: UUID(), temperature: attributed.temperature, temperatureText: attributed.temperatureText, temperatureUnitText: attributed.temperatureUnitText)]
            }
            
            step.timings = attributed.timeItems.map { RecipeStepTiming(id: UUID(), timeInSeconds: Double($0.timeInSeconds), timeText: $0.timeText, timeUnitText: $0.timeUnitText )}
        }
    }
}

private struct IngredientRow: View {
    @Binding var ingredient: RecipeIngredient
    @State private var attributed: AttributedString = ""
    let tint: Color
    let focusedID: FocusState<UUID?>.Binding
    
    var body: some View {
        HStack {
            EmojiPickerButton(emoji: $ingredient.emoji)
            
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
                        tint: .secondary
                    )
                }
                .overlay {
                    TextEditor(text: $attributed)
                        .padding(.horizontal, -4)
                        .padding(.vertical, -10)
                        .scrollDisabled(true)
                        .submitLabel(.done)
                        .focused(focusedID, equals: ingredient.id)
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

struct EmojiPickerButton: View {
    @Binding var emoji: String?
    @State private var isPicking = false
    
    var body: some View {
        Button { isPicking = true } label: {
            if let emoji {
                Text(emoji)
                    .font(.system(size: 28))
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.tertiary))
            } else {
                Image(systemName: "face.dashed")
                    .font(.system(size: 28))
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.primary.tertiary))
            }
        }
        .overlay(alignment: .topTrailing, content: {
            ZStack {
                Circle().fill(.blue).frame(width: 15, height: 15)
                Image(systemName: "pencil")
                    .font(.caption2)
            }
            .padding(.top, -3)
            .padding(.trailing, -3)
        })
        .sheet(isPresented: $isPicking) {
            EmojiEntrySheet(value: $emoji, isPresented: $isPicking)
                .presentationDetents([.height(180)])
                .presentationDragIndicator(.visible)
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
        dominantColorHex: "#FFFFFF",
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

