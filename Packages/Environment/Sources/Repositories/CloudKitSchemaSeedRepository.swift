import Dependencies
import Foundation
import Persistence
import SQLiteData

#if DEBUG
@MainActor
public final class CloudKitSchemaSeedRepository {

    @Dependency(\.defaultDatabase) private var database
    @Dependency(\.defaultSyncEngine) private var syncEngine

    public init() {}

    public func seedAllSyncedEntities() async throws {
        let ids = SeedIDs()
        let now = Date()

        try await database.write { db in
            try DBHome.upsert {
                DBHome(id: ids.home, name: "\(Self.prefix) Home")
            }
            .execute(db)

            try DBRecipe.upsert {
                DBRecipe(
                    id: ids.recipe,
                    title: "\(Self.prefix) Recipe",
                    description: "Creates the CloudKit schema for every synced recipe table.",
                    author: "Sporkast",
                    sourceUrl: "sporkast://cloudkit-schema-seed",
                    dominantColorHex: "#2563EB",
                    minutesToPrepare: 1,
                    minutesToCook: 1,
                    totalMins: 2,
                    serves: "1",
                    overallRating: 5,
                    totalRatings: 1,
                    summarisedRating: "Schema seed",
                    summarisedSuggestion: "Delete after promoting the CloudKit schema.",
                    dateAdded: now,
                    dateModified: now,
                    ingredientScale: 1,
                    ingredientUnitSystem: "metric",
                    homeId: ids.home
                )
            }
            .execute(db)

            try DBRecipeImage.upsert {
                DBRecipeImage(
                    recipeId: ids.recipe,
                    imageSourceUrl: "sporkast://cloudkit-schema-seed/image",
                    imageData: Data("schema-seed-image".utf8)
                )
            }
            .execute(db)

            try DBRecipeIngredientGroup.upsert {
                DBRecipeIngredientGroup(
                    id: ids.ingredientGroup,
                    recipeId: ids.recipe,
                    title: "\(Self.prefix) Ingredients",
                    sortIndex: 0
                )
            }
            .execute(db)

            try DBRecipeIngredient.upsert {
                DBRecipeIngredient(
                    id: ids.ingredient,
                    ingredientGroupId: ids.ingredientGroup,
                    sortIndex: 0,
                    rawIngredient: "1 schema seed",
                    quantity: 1,
                    quantityText: "1",
                    unit: "item",
                    unitText: "item",
                    ingredient: "schema seed",
                    extra: "CloudKit",
                    emojiDescriptor: "seed",
                    owned: false
                )
            }
            .execute(db)

            try DBRecipeStepGroup.upsert {
                DBRecipeStepGroup(
                    id: ids.stepGroup,
                    recipeId: ids.recipe,
                    title: "\(Self.prefix) Steps",
                    sortIndex: 0
                )
            }
            .execute(db)

            try DBRecipeStep.upsert {
                DBRecipeStep(
                    id: ids.step,
                    groupId: ids.stepGroup,
                    sortIndex: 0,
                    instruction: "Create CloudKit schema seed records."
                )
            }
            .execute(db)

            try DBRecipeStepTiming.upsert {
                DBRecipeStepTiming(
                    id: ids.stepTiming,
                    recipeStepId: ids.step,
                    timeInSeconds: 60,
                    timeText: "1",
                    timeUnitText: "minute"
                )
            }
            .execute(db)

            try DBRecipeStepTemperature.upsert {
                DBRecipeStepTemperature(
                    id: ids.stepTemperature,
                    recipeStepId: ids.step,
                    temperature: 180,
                    temperatureText: "180",
                    temperatureUnitText: "C"
                )
            }
            .execute(db)

            try DBRecipeStepLinkedIngredient.upsert {
                DBRecipeStepLinkedIngredient(
                    id: ids.stepLinkedIngredient,
                    recipeStepId: ids.step,
                    ingredientId: ids.ingredient,
                    sortIndex: 0
                )
            }
            .execute(db)

            try DBRecipeRating.upsert {
                DBRecipeRating(
                    id: ids.rating,
                    recipeId: ids.recipe,
                    rating: 5,
                    comment: "CloudKit schema seed"
                )
            }
            .execute(db)

            try DBRecipeFolder.upsert {
                DBRecipeFolder(
                    id: ids.parentFolder,
                    homeId: ids.home,
                    name: "\(Self.prefix) Parent Folder",
                    symbolName: "folder",
                    colorHex: "#F59E0B",
                    sortIndex: 0,
                    createdAt: now,
                    modifiedAt: now
                )
            }
            .execute(db)

            try DBRecipeFolder.upsert {
                DBRecipeFolder(
                    id: ids.childFolder,
                    homeId: ids.home,
                    name: "\(Self.prefix) Child Folder",
                    symbolName: "folder.fill",
                    colorHex: "#10B981",
                    sortIndex: 1,
                    createdAt: now,
                    modifiedAt: now
                )
            }
            .execute(db)

            try DBRecipeFolderHierarchy.upsert {
                DBRecipeFolderHierarchy(
                    id: ids.folderHierarchy,
                    parentFolderId: ids.parentFolder,
                    childFolderId: ids.childFolder
                )
            }
            .execute(db)

            try DBRecipeTag.upsert {
                DBRecipeTag(
                    id: ids.tag,
                    homeId: ids.home,
                    name: "\(Self.prefix) Tag",
                    colorHex: "#2563EB",
                    createdAt: now,
                    modifiedAt: now
                )
            }
            .execute(db)

            try DBRecipeFolderAssignment.upsert {
                DBRecipeFolderAssignment(
                    id: ids.folderAssignment,
                    recipeId: ids.recipe,
                    folderId: ids.childFolder,
                    assignedAt: now
                )
            }
            .execute(db)

            try DBRecipeTagAssignment.upsert {
                DBRecipeTagAssignment(
                    id: ids.tagAssignment,
                    recipeId: ids.recipe,
                    tagId: ids.tag,
                    assignedAt: now
                )
            }
            .execute(db)

            try DBMealplanEntry.upsert {
                DBMealplanEntry(
                    id: ids.mealplanEntry,
                    date: now,
                    index: 0,
                    noteText: "\(Self.prefix) Mealplan Entry",
                    recipeId: ids.recipe,
                    homeId: ids.home
                )
            }
            .execute(db)

            try DBShoppingList.upsert {
                DBShoppingList(
                    id: ids.shoppingList,
                    homeId: ids.home,
                    title: "\(Self.prefix) Shopping List",
                    createdAt: now,
                    modifiedAt: now,
                    isArchived: true
                )
            }
            .execute(db)

            try DBShoppingListItem.upsert {
                DBShoppingListItem(
                    id: ids.shoppingListItem,
                    title: "\(Self.prefix) Shopping Item",
                    listId: ids.shoppingList,
                    isComplete: false,
                    modifiedAt: now,
                    categoryIdentifier: "unknown",
                    categoryDisplayName: "Other",
                    categorySource: "schema-seed"
                )
            }
            .execute(db)

            try DBShoppingListItemIngredientLink.upsert {
                DBShoppingListItemIngredientLink(
                    id: ids.shoppingIngredientLink,
                    shoppingListItemId: ids.shoppingListItem,
                    ingredientId: ids.ingredient,
                    sourceScale: 1,
                    addedAt: now
                )
            }
            .execute(db)

            try DBShoppingListItemReminderLink.upsert {
                DBShoppingListItemReminderLink(
                    id: ids.shoppingReminderLink,
                    shoppingListItemId: ids.shoppingListItem,
                    reminderIdentifier: "sporkast-cloudkit-schema-seed",
                    reminderExternalIdentifier: "sporkast-cloudkit-schema-seed-external",
                    lastSyncedAt: now
                )
            }
            .execute(db)

            try DBShoppingListItemMealplanLink.upsert {
                DBShoppingListItemMealplanLink(
                    id: ids.shoppingMealplanLink,
                    shoppingListItemId: ids.shoppingListItem,
                    mealplanEntryId: ids.mealplanEntry,
                    addedAt: now
                )
            }
            .execute(db)
        }

        try await syncEngine.syncChanges()
    }
}

private extension CloudKitSchemaSeedRepository {
    nonisolated static let prefix = "__cloudkit_schema_seed__"

    struct SeedIDs {
        let home = UUID(uuidString: "00000000-0000-4000-8000-000000000001")!
        let recipe = UUID(uuidString: "00000000-0000-4000-8000-000000000002")!
        let ingredientGroup = UUID(uuidString: "00000000-0000-4000-8000-000000000003")!
        let ingredient = UUID(uuidString: "00000000-0000-4000-8000-000000000004")!
        let stepGroup = UUID(uuidString: "00000000-0000-4000-8000-000000000005")!
        let step = UUID(uuidString: "00000000-0000-4000-8000-000000000006")!
        let stepTiming = UUID(uuidString: "00000000-0000-4000-8000-000000000007")!
        let stepTemperature = UUID(uuidString: "00000000-0000-4000-8000-000000000008")!
        let stepLinkedIngredient = UUID(uuidString: "00000000-0000-4000-8000-000000000009")!
        let rating = UUID(uuidString: "00000000-0000-4000-8000-00000000000A")!
        let parentFolder = UUID(uuidString: "00000000-0000-4000-8000-00000000000B")!
        let childFolder = UUID(uuidString: "00000000-0000-4000-8000-00000000000C")!
        let folderHierarchy = UUID(uuidString: "00000000-0000-4000-8000-00000000000D")!
        let tag = UUID(uuidString: "00000000-0000-4000-8000-00000000000E")!
        let folderAssignment = UUID(uuidString: "00000000-0000-4000-8000-00000000000F")!
        let tagAssignment = UUID(uuidString: "00000000-0000-4000-8000-000000000010")!
        let mealplanEntry = UUID(uuidString: "00000000-0000-4000-8000-000000000011")!
        let shoppingList = UUID(uuidString: "00000000-0000-4000-8000-000000000012")!
        let shoppingListItem = UUID(uuidString: "00000000-0000-4000-8000-000000000013")!
        let shoppingIngredientLink = UUID(uuidString: "00000000-0000-4000-8000-000000000014")!
        let shoppingReminderLink = UUID(uuidString: "00000000-0000-4000-8000-000000000015")!
        let shoppingMealplanLink = UUID(uuidString: "00000000-0000-4000-8000-000000000016")!
    }
}
#endif
