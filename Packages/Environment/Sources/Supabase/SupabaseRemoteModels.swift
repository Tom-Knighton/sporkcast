//
//  SupabaseRemoteModels.swift
//  Environment
//
//  Created by Tom Knighton on 01/06/2026.
//

import Foundation
import Models
import Persistence

protocol SupabaseOriginTracked {
    var updatedBy: UUID? { get }
}

struct SupabaseHomeRow: Codable, Sendable, Identifiable {
    let id: UUID
    var name: String
    var createdAt: Date?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case name
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }

    init(_ home: DBHome) {
        id = home.id
        name = home.name
        createdAt = nil
        updatedAt = nil
    }
}

struct SupabaseHomeInviteRow: Codable, Sendable, Identifiable {
    let id: UUID
    let homeId: UUID
    let token: String
    let createdAt: Date?
    let expiresAt: Date?
    let acceptedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case token
        case createdAt = "created_at"
        case expiresAt = "expires_at"
        case acceptedAt = "accepted_at"
    }
}

struct SupabaseHomeMemberRow: Codable, Sendable {
    let homeId: UUID
    let userId: UUID
    let role: String

    enum CodingKeys: String, CodingKey {
        case homeId = "home_id"
        case userId = "user_id"
        case role
    }
}

struct SupabaseCreateInvitePayload: Codable, Sendable {
    let homeId: UUID
    let expiresAt: Date?

    enum CodingKeys: String, CodingKey {
        case homeId = "home_id"
        case expiresAt = "expires_at"
    }
}

struct SupabaseLeaveHomeParams: Codable, Sendable {
    let homeId: UUID
    let disbandIfOwner: Bool

    enum CodingKeys: String, CodingKey {
        case homeId = "p_home_id"
        case disbandIfOwner = "p_disband_if_owner"
    }
}

struct SupabaseRecipeRow: Codable, Sendable, Identifiable, SupabaseOriginTracked {
    let id: UUID
    var homeId: UUID?
    var title: String
    var description: String?
    var author: String?
    var sourceUrl: String
    var dominantColorHex: String?
    var minutesToPrepare: Double?
    var minutesToCook: Double?
    var totalMins: Double?
    var serves: String?
    var overallRating: Double?
    var totalRatings: Int
    var summarisedRating: String?
    var summarisedSuggestion: String?
    var dateAdded: Date
    var dateModified: Date
    var ingredientScale: Double
    var ingredientUnitSystem: String
    var deletedAt: Date?
    var updatedBy: UUID?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case title
        case description
        case author
        case sourceUrl = "source_url"
        case dominantColorHex = "dominant_color_hex"
        case minutesToPrepare = "minutes_to_prepare"
        case minutesToCook = "minutes_to_cook"
        case totalMins = "total_mins"
        case serves
        case overallRating = "overall_rating"
        case totalRatings = "total_ratings"
        case summarisedRating = "summarised_rating"
        case summarisedSuggestion = "summarised_suggestion"
        case dateAdded = "date_added"
        case dateModified = "date_modified"
        case ingredientScale = "ingredient_scale"
        case ingredientUnitSystem = "ingredient_unit_system"
        case deletedAt = "deleted_at"
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
    }

    init(_ recipe: DBRecipe) {
        id = recipe.id
        homeId = recipe.homeId
        title = recipe.title
        description = recipe.description
        author = recipe.author
        sourceUrl = recipe.sourceUrl
        dominantColorHex = recipe.dominantColorHex
        minutesToPrepare = recipe.minutesToPrepare
        minutesToCook = recipe.minutesToCook
        totalMins = recipe.totalMins
        serves = recipe.serves
        overallRating = recipe.overallRating
        totalRatings = recipe.totalRatings
        summarisedRating = recipe.summarisedRating
        summarisedSuggestion = recipe.summarisedSuggestion
        dateAdded = recipe.dateAdded
        dateModified = recipe.dateModified
        ingredientScale = recipe.ingredientScale
        ingredientUnitSystem = recipe.ingredientUnitSystem
        deletedAt = nil
        updatedBy = nil
        updatedAt = nil
    }

    func localRow() -> DBRecipe {
        DBRecipe(
            id: id,
            title: title,
            description: description,
            author: author,
            sourceUrl: sourceUrl,
            dominantColorHex: dominantColorHex,
            minutesToPrepare: minutesToPrepare,
            minutesToCook: minutesToCook,
            totalMins: totalMins,
            serves: serves,
            overallRating: overallRating,
            totalRatings: totalRatings,
            summarisedRating: summarisedRating,
            summarisedSuggestion: summarisedSuggestion,
            dateAdded: dateAdded,
            dateModified: dateModified,
            ingredientScale: ingredientScale,
            ingredientUnitSystem: ingredientUnitSystem,
            homeId: homeId
        )
    }
}

struct SupabaseRecipeImageRow: Codable, Sendable, Identifiable {
    let recipeId: UUID
    var imageSourceUrl: String?
    var storagePath: String?
    var updatedAt: Date?

    var id: UUID { recipeId }

    enum CodingKeys: String, CodingKey {
        case recipeId = "recipe_id"
        case imageSourceUrl = "image_source_url"
        case storagePath = "storage_path"
        case updatedAt = "updated_at"
    }

    init(_ image: DBRecipeImage) {
        recipeId = image.recipeId
        imageSourceUrl = image.imageSourceUrl
        storagePath = nil
        updatedAt = nil
    }

    func localRow() -> DBRecipeImage {
        DBRecipeImage(recipeId: recipeId, imageSourceUrl: imageSourceUrl, imageData: nil)
    }
}

struct SupabaseRecipeIngredientSectionRow: Codable, Sendable, Identifiable {
    let id: UUID
    let recipeId: UUID
    var sortIndex: Int
    var title: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case sortIndex = "sort_index"
        case title
    }

    var ingredientGroup: DBRecipeIngredientGroup {
        DBRecipeIngredientGroup(id: id, recipeId: recipeId, title: title, sortIndex: sortIndex)
    }
}

struct SupabaseRecipeIngredientRow: Codable, Sendable, Identifiable {
    let id: UUID
    let ingredientGroupId: UUID
    var sortIndex: Int
    var rawIngredient: String
    var quantity: Double?
    var quantityText: String?
    var unit: String?
    var unitText: String?
    var ingredient: String?
    var extra: String?
    var emojiDescriptor: String?
    var owned: Bool
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case ingredientGroupId = "ingredient_group_id"
        case sortIndex = "sort_index"
        case rawIngredient = "raw_ingredient"
        case quantity
        case quantityText = "quantity_text"
        case unit
        case unitText = "unit_text"
        case ingredient
        case extra
        case emojiDescriptor = "emoji_descriptor"
        case owned
        case updatedAt = "updated_at"
    }

    init(_ ingredient: DBRecipeIngredient) {
        id = ingredient.id
        ingredientGroupId = ingredient.ingredientGroupId
        sortIndex = ingredient.sortIndex
        rawIngredient = ingredient.rawIngredient
        quantity = ingredient.quantity
        quantityText = ingredient.quantityText
        unit = ingredient.unit
        unitText = ingredient.unitText
        self.ingredient = ingredient.ingredient
        extra = ingredient.extra
        emojiDescriptor = ingredient.emojiDescriptor
        owned = ingredient.owned
        updatedAt = nil
    }

    func localRow() -> DBRecipeIngredient {
        DBRecipeIngredient(
            id: id,
            ingredientGroupId: ingredientGroupId,
            sortIndex: sortIndex,
            rawIngredient: rawIngredient,
            quantity: quantity,
            quantityText: quantityText,
            unit: unit,
            unitText: unitText,
            ingredient: ingredient,
            extra: extra,
            emojiDescriptor: emojiDescriptor,
            owned: owned
        )
    }
}

struct SupabaseRecipeStepSectionRow: Codable, Sendable, Identifiable {
    let id: UUID
    let recipeId: UUID
    var sortIndex: Int
    var title: String

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case sortIndex = "sort_index"
        case title
    }

    var stepGroup: DBRecipeStepGroup {
        DBRecipeStepGroup(id: id, recipeId: recipeId, title: title, sortIndex: sortIndex)
    }
}

struct SupabaseRecipeStepRow: Codable, Sendable, Identifiable {
    let id: UUID
    let groupId: UUID
    var sortIndex: Int
    var instruction: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case groupId = "group_id"
        case sortIndex = "sort_index"
        case instruction
        case updatedAt = "updated_at"
    }

    init(_ step: DBRecipeStep) {
        id = step.id
        groupId = step.groupId
        sortIndex = step.sortIndex
        instruction = step.instruction
        updatedAt = nil
    }

    func localRow() -> DBRecipeStep {
        DBRecipeStep(id: id, groupId: groupId, sortIndex: sortIndex, instruction: instruction)
    }
}

struct SupabaseRecipeStepTimingRow: Codable, Sendable, Identifiable {
    let id: UUID
    let recipeStepId: UUID
    var timeInSeconds: Double
    var timeText: String
    var timeUnitText: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recipeStepId = "recipe_step_id"
        case timeInSeconds = "time_in_seconds"
        case timeText = "time_text"
        case timeUnitText = "time_unit_text"
        case updatedAt = "updated_at"
    }

    init(_ timing: DBRecipeStepTiming) {
        id = timing.id
        recipeStepId = timing.recipeStepId
        timeInSeconds = timing.timeInSeconds
        timeText = timing.timeText
        timeUnitText = timing.timeUnitText
        updatedAt = nil
    }

    func localRow() -> DBRecipeStepTiming {
        DBRecipeStepTiming(id: id, recipeStepId: recipeStepId, timeInSeconds: timeInSeconds, timeText: timeText, timeUnitText: timeUnitText)
    }
}

struct SupabaseRecipeStepTemperatureRow: Codable, Sendable, Identifiable {
    let id: UUID
    let recipeStepId: UUID
    var temperature: Double
    var temperatureText: String
    var temperatureUnitText: String
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recipeStepId = "recipe_step_id"
        case temperature
        case temperatureText = "temperature_text"
        case temperatureUnitText = "temperature_unit_text"
        case updatedAt = "updated_at"
    }

    init(_ temperature: DBRecipeStepTemperature) {
        id = temperature.id
        recipeStepId = temperature.recipeStepId
        self.temperature = temperature.temperature
        temperatureText = temperature.temperatureText
        temperatureUnitText = temperature.temperatureUnitText
        updatedAt = nil
    }

    func localRow() -> DBRecipeStepTemperature {
        DBRecipeStepTemperature(id: id, recipeStepId: recipeStepId, temperature: temperature, temperatureText: temperatureText, temperatureUnitText: temperatureUnitText)
    }
}

struct SupabaseRecipeStepLinkedIngredientRow: Codable, Sendable, Identifiable {
    let id: UUID
    let recipeStepId: UUID
    let ingredientId: UUID
    var sortIndex: Int
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recipeStepId = "recipe_step_id"
        case ingredientId = "ingredient_id"
        case sortIndex = "sort_index"
        case updatedAt = "updated_at"
    }

    init(_ linkedIngredient: DBRecipeStepLinkedIngredient) {
        id = linkedIngredient.id
        recipeStepId = linkedIngredient.recipeStepId
        ingredientId = linkedIngredient.ingredientId
        sortIndex = linkedIngredient.sortIndex
        updatedAt = nil
    }

    func localRow() -> DBRecipeStepLinkedIngredient {
        DBRecipeStepLinkedIngredient(id: id, recipeStepId: recipeStepId, ingredientId: ingredientId, sortIndex: sortIndex)
    }
}

struct SupabaseFullRecipePayload: Sendable {
    var recipe: SupabaseRecipeRow
    var image: SupabaseRecipeImageRow?
    var ingredientSections: [SupabaseRecipeIngredientSectionRow]
    var ingredients: [SupabaseRecipeIngredientRow]
    var stepSections: [SupabaseRecipeStepSectionRow]
    var steps: [SupabaseRecipeStepRow]
    var stepTimings: [SupabaseRecipeStepTimingRow]
    var stepTemperatures: [SupabaseRecipeStepTemperatureRow]
    var stepLinkedIngredients: [SupabaseRecipeStepLinkedIngredientRow]
    var ratings: [DBRecipeRating]

    init(_ fullRecipe: FullDBRecipe) {
        recipe = SupabaseRecipeRow(fullRecipe.recipe)
        image = fullRecipe.imageData.map(SupabaseRecipeImageRow.init)

        let ingredientGroups = fullRecipe.ingredientGroups.sorted { $0.sortIndex < $1.sortIndex }
        ingredientSections = ingredientGroups.map { group in
            SupabaseRecipeIngredientSectionRow(
                id: group.id,
                recipeId: group.recipeId,
                sortIndex: group.sortIndex,
                title: group.title
            )
        }
        ingredients = fullRecipe.ingredients
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(SupabaseRecipeIngredientRow.init)

        let stepGroups = fullRecipe.stepGroups.sorted { $0.sortIndex < $1.sortIndex }
        stepSections = stepGroups.map { group in
            SupabaseRecipeStepSectionRow(
                id: group.id,
                recipeId: group.recipeId,
                sortIndex: group.sortIndex,
                title: group.title
            )
        }
        steps = fullRecipe.steps
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(SupabaseRecipeStepRow.init)
        stepTimings = fullRecipe.timings.map(SupabaseRecipeStepTimingRow.init)
        stepTemperatures = fullRecipe.temperatures.map(SupabaseRecipeStepTemperatureRow.init)
        stepLinkedIngredients = fullRecipe.stepLinkedIngredients
            .sorted { $0.sortIndex < $1.sortIndex }
            .map(SupabaseRecipeStepLinkedIngredientRow.init)

        ratings = fullRecipe.ratings
    }
}

struct SupabaseRecipeFolderRow: Codable, Sendable, Identifiable, SupabaseOriginTracked {
    let id: UUID
    let homeId: UUID?
    var name: String
    var symbolName: String
    var colorHex: String
    var sortIndex: Int
    var createdAt: Date
    var modifiedAt: Date
    var updatedBy: UUID?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case name
        case symbolName = "symbol_name"
        case colorHex = "color_hex"
        case sortIndex = "sort_index"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
    }

    init(_ folder: DBRecipeFolder) {
        id = folder.id
        homeId = folder.homeId
        name = folder.name
        symbolName = folder.symbolName
        colorHex = folder.colorHex
        sortIndex = folder.sortIndex
        createdAt = folder.createdAt
        modifiedAt = folder.modifiedAt
        updatedBy = nil
        updatedAt = nil
    }

    func localRow() -> DBRecipeFolder {
        DBRecipeFolder(
            id: id,
            homeId: homeId,
            name: name,
            symbolName: symbolName,
            colorHex: colorHex,
            sortIndex: sortIndex,
            createdAt: createdAt,
            modifiedAt: modifiedAt
        )
    }
}

struct SupabaseRecipeFolderHierarchyRow: Codable, Sendable, Identifiable {
    let id: UUID
    let parentFolderId: UUID
    let childFolderId: UUID
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case parentFolderId = "parent_folder_id"
        case childFolderId = "child_folder_id"
        case updatedAt = "updated_at"
    }

    init(_ hierarchy: DBRecipeFolderHierarchy) {
        id = hierarchy.id
        parentFolderId = hierarchy.parentFolderId
        childFolderId = hierarchy.childFolderId
        updatedAt = nil
    }

    func localRow() -> DBRecipeFolderHierarchy {
        DBRecipeFolderHierarchy(id: id, parentFolderId: parentFolderId, childFolderId: childFolderId)
    }
}

struct SupabaseRecipeFolderAssignmentRow: Codable, Sendable, Identifiable {
    let id: UUID
    let recipeId: UUID
    let folderId: UUID
    var assignedAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case folderId = "folder_id"
        case assignedAt = "assigned_at"
        case updatedAt = "updated_at"
    }

    init(_ assignment: DBRecipeFolderAssignment) {
        id = assignment.id
        recipeId = assignment.recipeId
        folderId = assignment.folderId
        assignedAt = assignment.assignedAt
        updatedAt = nil
    }

    func localRow() -> DBRecipeFolderAssignment {
        DBRecipeFolderAssignment(id: id, recipeId: recipeId, folderId: folderId, assignedAt: assignedAt)
    }
}

struct SupabaseRecipeTagRow: Codable, Sendable, Identifiable, SupabaseOriginTracked {
    let id: UUID
    let homeId: UUID?
    var name: String
    var colorHex: String
    var createdAt: Date
    var modifiedAt: Date
    var updatedBy: UUID?
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case name
        case colorHex = "color_hex"
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
    }

    init(_ tag: DBRecipeTag) {
        id = tag.id
        homeId = tag.homeId
        name = tag.name
        colorHex = tag.colorHex
        createdAt = tag.createdAt
        modifiedAt = tag.modifiedAt
        updatedBy = nil
        updatedAt = nil
    }

    func localRow() -> DBRecipeTag {
        DBRecipeTag(id: id, homeId: homeId, name: name, colorHex: colorHex, createdAt: createdAt, modifiedAt: modifiedAt)
    }
}

struct SupabaseRecipeTagAssignmentRow: Codable, Sendable, Identifiable {
    let id: UUID
    let recipeId: UUID
    let tagId: UUID
    var assignedAt: Date
    var updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case recipeId = "recipe_id"
        case tagId = "tag_id"
        case assignedAt = "assigned_at"
        case updatedAt = "updated_at"
    }

    init(_ assignment: DBRecipeTagAssignment) {
        id = assignment.id
        recipeId = assignment.recipeId
        tagId = assignment.tagId
        assignedAt = assignment.assignedAt
        updatedAt = nil
    }

    func localRow() -> DBRecipeTagAssignment {
        DBRecipeTagAssignment(id: id, recipeId: recipeId, tagId: tagId, assignedAt: assignedAt)
    }
}

struct SupabaseMealplanEntryRow: Codable, Sendable, Identifiable, SupabaseOriginTracked {
    let id: UUID
    let homeId: UUID?
    var date: Date
    var sortIndex: Int
    var noteText: String?
    var recipeId: UUID?
    var updatedBy: UUID?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case date
        case sortIndex = "sort_index"
        case noteText = "note_text"
        case recipeId = "recipe_id"
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(_ entry: DBMealplanEntry) {
        id = entry.id
        homeId = entry.homeId
        date = entry.date
        sortIndex = entry.index
        noteText = entry.noteText
        recipeId = entry.recipeId
        updatedBy = nil
        updatedAt = nil
        deletedAt = nil
    }

    func localRow() -> DBMealplanEntry {
        DBMealplanEntry(
            id: id,
            date: date,
            index: sortIndex,
            noteText: noteText,
            recipeId: recipeId,
            homeId: homeId
        )
    }
}

struct SupabaseShoppingListRow: Codable, Sendable, Identifiable, SupabaseOriginTracked {
    let id: UUID
    let homeId: UUID?
    var title: String
    var createdAt: Date
    var modifiedAt: Date
    var isArchived: Bool
    var updatedBy: UUID?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case title
        case createdAt = "created_at"
        case modifiedAt = "modified_at"
        case isArchived = "is_archived"
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(_ list: DBShoppingList) {
        id = list.id
        homeId = list.homeId
        title = list.title
        createdAt = list.createdAt
        modifiedAt = list.modifiedAt
        isArchived = list.isArchived
        updatedBy = nil
        updatedAt = nil
        deletedAt = nil
    }

    func localRow() -> DBShoppingList {
        DBShoppingList(
            id: id,
            homeId: homeId,
            title: title,
            createdAt: createdAt,
            modifiedAt: modifiedAt,
            isArchived: isArchived
        )
    }
}

struct SupabaseShoppingListItemRow: Codable, Sendable, Identifiable, SupabaseOriginTracked {
    let id: UUID
    let homeId: UUID?
    let listId: UUID
    var title: String
    var isComplete: Bool
    var modifiedAt: Date
    var categoryIdentifier: String?
    var categoryDisplayName: String
    var categorySource: String
    var updatedBy: UUID?
    var updatedAt: Date?
    var deletedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case listId = "list_id"
        case title
        case isComplete = "is_complete"
        case modifiedAt = "modified_at"
        case categoryIdentifier = "category_identifier"
        case categoryDisplayName = "category_display_name"
        case categorySource = "category_source"
        case updatedBy = "updated_by"
        case updatedAt = "updated_at"
        case deletedAt = "deleted_at"
    }

    init(_ item: DBShoppingListItem, homeId: UUID?) {
        id = item.id
        self.homeId = homeId
        listId = item.listId
        title = item.title
        isComplete = item.isComplete
        modifiedAt = item.modifiedAt
        categoryIdentifier = item.categoryIdentifier
        categoryDisplayName = item.categoryDisplayName
        categorySource = item.categorySource
        updatedBy = nil
        updatedAt = nil
        deletedAt = nil
    }

    func localRow() -> DBShoppingListItem {
        DBShoppingListItem(
            id: id,
            title: title,
            listId: listId,
            isComplete: isComplete,
            modifiedAt: modifiedAt,
            categoryIdentifier: categoryIdentifier,
            categoryDisplayName: categoryDisplayName,
            categorySource: categorySource
        )
    }
}

struct SupabaseShoppingListItemIngredientLinkRow: Codable, Sendable, Identifiable {
    let id: UUID
    let homeId: UUID?
    let shoppingListItemId: UUID
    let ingredientId: UUID
    let sourceScale: Double?
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case shoppingListItemId = "shopping_list_item_id"
        case ingredientId = "ingredient_id"
        case sourceScale = "source_scale"
        case addedAt = "added_at"
    }

    init(_ link: DBShoppingListItemIngredientLink, homeId: UUID?) {
        id = link.id
        self.homeId = homeId
        shoppingListItemId = link.shoppingListItemId
        ingredientId = link.ingredientId
        sourceScale = link.sourceScale
        addedAt = link.addedAt
    }

    func localRow() -> DBShoppingListItemIngredientLink {
        DBShoppingListItemIngredientLink(
            id: id,
            shoppingListItemId: shoppingListItemId,
            ingredientId: ingredientId,
            sourceScale: sourceScale,
            addedAt: addedAt
        )
    }
}

struct SupabaseShoppingListItemMealplanLinkRow: Codable, Sendable, Identifiable {
    let id: UUID
    let homeId: UUID?
    let shoppingListItemId: UUID
    let mealplanEntryId: UUID
    let addedAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case homeId = "home_id"
        case shoppingListItemId = "shopping_list_item_id"
        case mealplanEntryId = "mealplan_entry_id"
        case addedAt = "added_at"
    }

    init(_ link: DBShoppingListItemMealplanLink, homeId: UUID?) {
        id = link.id
        self.homeId = homeId
        shoppingListItemId = link.shoppingListItemId
        mealplanEntryId = link.mealplanEntryId
        addedAt = link.addedAt
    }

    func localRow() -> DBShoppingListItemMealplanLink {
        DBShoppingListItemMealplanLink(
            id: id,
            shoppingListItemId: shoppingListItemId,
            mealplanEntryId: mealplanEntryId,
            addedAt: addedAt
        )
    }
}
