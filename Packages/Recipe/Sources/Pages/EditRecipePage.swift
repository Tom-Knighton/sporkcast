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
    @Environment(\.homeServices) private var homes
    @Environment(\.flagKit) private var flagKit

    private let recipe: Recipe
    @State private var editingRecipe: Recipe
    @State private var organizationRepository = RecipeOrganizationRepository()
    
    @State private var totalTime: Duration = .seconds(0)
    @State private var cookTime: Duration = .seconds(0)
    @State private var prepTime: Duration = .seconds(0)
    @State private var colour: Color
    @State private var errorMessage: String? = nil
    @State private var showErrorMessage: Bool = false
    @State private var selectedImageItem: PhotosPickerItem? = nil
    @State private var selectedImageData: Data? = nil
    @State private var selectedFolderIDs: Set<UUID> = []
    @State private var selectedTagIDs: Set<UUID> = []
    @State private var newFolderName = ""
    @State private var newTagName = ""
    @State private var isProPaywallPresented = false
    
    @FocusState private var focusedIngredientID: UUID?
    @FocusState private var focusedStepID: UUID?
    
    public init(recipe: Recipe) {
        self.recipe = recipe
        var sorted = recipe
        sorted.ingredientSections.sort { $0.sortIndex < $1.sortIndex }
        for i in sorted.ingredientSections.indices {
            sorted.ingredientSections[i].ingredients.sort { $0.sortIndex < $1.sortIndex }
        }
        sorted.stepSections.sort { $0.sortIndex < $1.sortIndex }
        for i in sorted.stepSections.indices {
            sorted.stepSections[i].steps.sort { $0.sortIndex < $1.sortIndex }
        }
        self._editingRecipe = State(wrappedValue: sorted)
        
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
                    if hasRecipeOrganizationProAccess {
                        organizationSection()
                    } else {
                        lockedOrganizationSection()
                    }
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
        .task {
            loadCurrentOrganization()
        }
        .sheet(isPresented: $isProPaywallPresented) {
            ProPaywallView()
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
    private func organizationSection() -> some View {
        Section("Folders & Tags") {
            if organizationRepository.folders(in: homes.home?.id).isEmpty {
                ContentUnavailableView("No Folders", systemImage: "folder", description: Text("Create folders for menus, prep batches, events, or family favourites."))
            } else {
                ForEach(organizationRepository.folders(in: homes.home?.id)) { folder in
                    OrganizationSelectionRow(
                        title: folder.name,
                        systemImage: folder.symbolName,
                        isSelected: selectedFolderIDs.contains(folder.id),
                        indentation: folderDepth(folder)
                    ) {
                        toggleFolder(folder.id)
                    }
                }
            }

            InlineOrganizationCreateRow(title: "New Folder", text: $newFolderName, action: createFolder)

            if organizationRepository.tags(in: homes.home?.id).isEmpty {
                ContentUnavailableView("No Tags", systemImage: "tag", description: Text("Create tags for cuisine, dietary notes, prep style, or station planning."))
            } else {
                ForEach(organizationRepository.tags(in: homes.home?.id)) { tag in
                    OrganizationSelectionRow(
                        title: tag.name,
                        systemImage: "tag",
                        isSelected: selectedTagIDs.contains(tag.id),
                        indentation: 0
                    ) {
                        toggleTag(tag.id)
                    }
                }
            }

            InlineOrganizationCreateRow(title: "New Tag", text: $newTagName, action: createTag)
        }
    }

    @ViewBuilder
    private func lockedOrganizationSection() -> some View {
        Section("Folders & Tags") {
            Button {
                isProPaywallPresented = true
            } label: {
                HStack(spacing: 12) {
                    Image(systemName: "lock.fill")
                        .foregroundStyle(.secondary)
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 3) {
                        Text("Unlock recipe organization")
                            .font(.headline)
                            .foregroundStyle(.primary)

                        Text("Add this recipe to folders, subfolders, and tags with Sporkast Pro.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tertiary)
                }
            }
            .buttonStyle(.plain)
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
                    StepRow(step: $step, focusedStepID: $focusedStepID, tint: Color(hex: editingRecipe.dominantColorHex ?? "#FFFFFF") ?? .white, allIngredients: self.editingRecipe.ingredientSections.flatMap(\.ingredients))
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
                        stepSection.steps.append(.init(id: newID, sortIndex: stepSection.steps.count, instructionText: "", timings: [], temperatures: [], linkedIngredients: []))
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
            
            let (newRecipe, newImage, newIngGroups, newIngs, newStepGroups, newSteps, newStepTimings, newStepTemps, newRatings, newLinkedIngredients) = await Recipe.entites(from: editingRecipe)

            try await db.write { [newRecipe, newImage, newIngGroups, newIngs, newStepGroups, newSteps, newStepTimings, newStepTemps, newRatings] db in
                
                try DBRecipe
                    .upsert { newRecipe }
                    .execute(db)
                try DBRecipeImage
                    .upsert { newImage }
                    .execute(db)
                
                // Remove & Reinsert ingredients & temps
                try DBRecipeIngredientGroup
                    .where { $0.recipeId.eq(newRecipe.id) }
                    .delete()
                    .execute(db)
                try DBRecipeIngredientGroup
                    .insert { newIngGroups }
                    .execute(db)
                try DBRecipeIngredient
                    .insert { newIngs}
                    .execute(db)
                try DBRecipeStepGroup
                    .where { $0.recipeId.eq(newRecipe.id) }
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
                try DBRecipeStepLinkedIngredient
                    .insert { newLinkedIngredients }
                    .execute(db)
                
                // Ratings
                try DBRecipeRating
                    .where { $0.recipeId.eq(newRecipe.id) }
                    .delete()
                    .execute(db)
                try DBRecipeRating
                    .insert { newRatings }
                    .execute(db)
            }

            if hasRecipeOrganizationProAccess {
                try await organizationRepository.setOrganization(
                    for: editingRecipe,
                    folderIDs: selectedFolderIDs,
                    tagIDs: selectedTagIDs
                )
            }
            
            self.dismiss()
        } catch {
            self.errorMessage = "Failed to save recipe."
            return
        }
    }

    private func loadCurrentOrganization() {
        selectedFolderIDs = organizationRepository.currentFolderIDs(for: recipe.id)
        selectedTagIDs = organizationRepository.currentTagIDs(for: recipe.id)
    }

    private func toggleFolder(_ id: UUID) {
        if selectedFolderIDs.contains(id) {
            selectedFolderIDs.remove(id)
        } else {
            selectedFolderIDs.insert(id)
        }
    }

    private func toggleTag(_ id: UUID) {
        if selectedTagIDs.contains(id) {
            selectedTagIDs.remove(id)
        } else {
            selectedTagIDs.insert(id)
        }
    }

    private func createFolder() {
        let name = newFolderName
        Task {
            do {
                if let folder = try await organizationRepository.createFolder(name: name, homeId: homes.home?.id) {
                    selectedFolderIDs.insert(folder.id)
                    newFolderName = ""
                }
            } catch {
                errorMessage = "Failed to create folder."
            }
        }
    }

    private func createTag() {
        let name = newTagName
        Task {
            do {
                if let tag = try await organizationRepository.createTag(name: name, homeId: homes.home?.id) {
                    selectedTagIDs.insert(tag.id)
                    newTagName = ""
                }
            } catch {
                errorMessage = "Failed to create tag."
            }
        }
    }

    private func folderDepth(_ folder: RecipeFolder) -> Int {
        var depth = 0
        var currentParentID = folder.parentFolderId

        while let parentID = currentParentID,
              let parent = organizationRepository.folder(id: parentID),
              depth < 8 {
            depth += 1
            currentParentID = parent.parentFolderId
        }

        return depth
    }

    private var hasRecipeOrganizationProAccess: Bool {
        flagKit.isEnabled(.recipeOrganizationPro, default: false)
    }
}

private struct OrganizationSelectionRow: View {
    let title: String
    let systemImage: String
    let isSelected: Bool
    let indentation: Int
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                if indentation > 0 {
                    Spacer()
                        .frame(width: CGFloat(indentation) * 18)
                }

                Image(systemName: systemImage)
                    .foregroundStyle(.secondary)
                    .frame(width: 24)

                Text(title)
                    .foregroundStyle(.primary)

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? AnyShapeStyle(.tint) : AnyShapeStyle(.secondary))
            }
        }
        .buttonStyle(.plain)
    }
}

private struct InlineOrganizationCreateRow: View {
    let title: String
    @Binding var text: String
    let action: () -> Void

    private var canSubmit: Bool {
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        HStack {
            TextField(title, text: $text)
                .textInputAutocapitalization(.words)
                .submitLabel(.done)
                .onSubmit(submit)

            Button(action: submit) {
                Label("Add", systemImage: "plus.circle.fill")
            }
            .buttonStyle(.glass)
            .disabled(!canSubmit)
        }
    }

    private func submit() {
        guard canSubmit else { return }
        action()
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
                    .init(id: UUID(), sortIndex: 0, instructionText: "Turn the oven to 180°C and pre-heat for 20 minutes", timings: [.init(id: UUID(), timeInSeconds: 1200, timeText: "20", timeUnitText: "minutes")], temperatures: [.init(id: UUID(), temperature: 180, temperatureText: "180°C", temperatureUnitText: "C")], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 1, instructionText: "Toss cooked pasta with 3 large eggs and cheese off the heat.", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 2, instructionText: "Do a third thing", timings: [], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 3, instructionText: "And a fourth", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 4, instructionText: "And a fifth", timings: [], temperatures: [], linkedIngredients: []),
                    .init(id: UUID(), sortIndex: 5, instructionText: "And a sixth!", timings: [.init(id: UUID(), timeInSeconds: 60, timeText: "1", timeUnitText: "minute")], temperatures: [], linkedIngredients: [])
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
