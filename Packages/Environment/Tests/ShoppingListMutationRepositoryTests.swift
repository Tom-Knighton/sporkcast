import Testing
@testable import Environment

@Test func mergedTitleAddsQuantitiesForSameIngredient() {
    let merged = ShoppingListItemQuantityMerger.mergedTitle(existing: "2 eggs", incoming: "2 eggs")
    #expect(merged == "4 eggs")
}

@Test func mergedTitleAddsImplicitQuantitiesForManualEntries() {
    let merged = ShoppingListItemQuantityMerger.mergedTitle(existing: "milk", incoming: "milk")
    #expect(merged == "2 milk")
}

@Test func parsedTitleStripsMultiplierPrefixFromMergeKey() {
    let parsed = ShoppingListItemQuantityMerger.parsedTitle("2 x tomatoes")
    #expect(parsed.normalizedMergeKey == "tomatoes")
}

@Test func mergedTitleSupportsFractionsAndFormatsResult() {
    let merged = ShoppingListItemQuantityMerger.mergedTitle(existing: "1/2 cup sugar", incoming: "1/2 cup sugar")
    #expect(merged == "1 cup sugar")
}
