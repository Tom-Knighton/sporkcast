@testable import API
import Foundation
import Models
import Testing
@testable import RecipeImporting

@Test func apiImportKeepsStructuredValuesAndDoesNotRequestTextFallback() async throws {
    let dto = RecipeDTOMockBuilder()
        .withIngredients([.init(quantity: 7, quantityText: "seven", minQuantity: 7, maxQuantity: 7,
            unit: "custom-unit", unitText: "custom", ingredient: "structured ingredient", extra: "API extra",
            fullIngredient: "a little flour", alternativeQuantities: [])])
        .withSteps([.init(title: "Bake", steps: [.init(step: "Cook until done.",
            times: [.init(timeInSeconds: 123, timeText: "API time", timeUnitText: "seconds")],
            temperatures: [.init(temperature: 187, temperatureUnitText: "C", temperatureText: "API temp")])])])
        .build()
    let client = StructuredImportClient(dto: dto)
    let result = try await RecipeImportCoordinator(client: client).prepareImport(
        from: .webURL(URL(string: "https://example.com/structured")!), homeId: nil)
    let recipe = try #require(result.candidates.first?.recipe)
    let ingredient = try #require(recipe.ingredientSections.first?.ingredients.first)
    let step = try #require(recipe.stepSections.first?.steps.first)
    #expect(ingredient.quantity?.quantity == 7)
    #expect(ingredient.ingredientPart == "structured ingredient")
    #expect(ingredient.unit?.unit == "custom-unit")
    #expect(step.timings.first?.timeInSeconds == 123)
    #expect(step.temperatures.first?.temperature == 187)
    #expect(client.paths == ["Parser/Parse"])
}

@Test func completeSafariImportDoesNotContactAPI() async throws {
    let client = StructuredImportClient(dto: RecipeDTOMockBuilder().build())
    let coordinator = RecipeImportCoordinator(client: client, sharedPageReader: {
        RecipeSchemaParser.parse(scripts: [schemaFixture], sourceURL: $0)
    })
    let result = try await coordinator.prepareImport(from: .webURL(sourceURL), homeId: nil)
    #expect(client.paths.isEmpty)
    #expect(result.candidates.first?.recipe.title == "Soup & toast")
    #expect(result.candidates.first?.recipe.stepSections.first?.steps.first?.timings.first?.timeInSeconds == 900)
}

@Test func safariSchemaParsesGraphSectionsRatingsAndDurations() throws {
    let record = try #require(RecipeSchemaParser.parse(scripts: [schemaFixture], sourceURL: sourceURL))
    #expect(record.title == "Soup & toast")
    #expect(record.author == "Cook")
    #expect(record.prepMinutes == 5)
    #expect(record.totalMinutes == 20)
    #expect(record.stepSections.first?.title == "Soup")
    #expect(record.stepSections.first?.steps == ["Simmer for 15 minutes."])
    #expect(record.overallRating == 4.5)
    #expect(record.ratings.first?.comment == "Lovely & simple")
}

@Test func safariIncompleteAndMalformedMetadataFallsBack() {
    #expect(RecipeSchemaParser.parse(scripts: ["not JSON", "{\"@type\":\"Recipe\",\"name\":\"Title only\"}"], sourceURL: sourceURL) == nil)
}

@Test func safariSnapshotIsConsumedAndMustMatchFreshPage() throws {
    let suite = "RecipeImportTests.\(UUID())"
    let defaults = try #require(UserDefaults(suiteName: suite))
    defer { defaults.removePersistentDomain(forName: suite) }
    func store(url: String, age: TimeInterval) throws {
        defaults.set(try JSONSerialization.data(withJSONObject: [
            "url": url, "createdAt": Date().timeIntervalSince1970 - age, "jsonLD": [schemaFixture]
        ]), forKey: SharedRecipePageReader.defaultsKey)
    }
    try store(url: sourceURL.absoluteString, age: 0)
    #expect(SharedRecipePageReader.takeRecipe(for: sourceURL, defaults: defaults)?.title == "Soup & toast")
    #expect(SharedRecipePageReader.takeRecipe(for: sourceURL, defaults: defaults) == nil)
    try store(url: sourceURL.absoluteString, age: 301)
    #expect(SharedRecipePageReader.takeRecipe(for: sourceURL, defaults: defaults) == nil)
    try store(url: "https://other.example/recipe", age: 0)
    #expect(SharedRecipePageReader.takeRecipe(for: sourceURL, defaults: defaults) == nil)
}

@Test func duplicateSummaryRecognizesSourceBeforeTitleAndPreservesMeaningfulQueries() {
    let existing = RecipeDuplicateSummary(id: UUID(), title: "Old title", sourceURL: "https://example.com/recipe?id=1")
    let renamed = RecipeDuplicateSummary(id: UUID(), title: "Renamed", sourceURL: "https://EXAMPLE.com/recipe?id=1&utm_source=safari#recipe")
    let different = RecipeDuplicateSummary(id: UUID(), title: "Other", sourceURL: "https://example.com/recipe?id=2")
    #expect(renamed.duplicateSimilarity(with: existing).score == 1)
    #expect(different.duplicateSimilarity(with: existing).score == 0)
}

private let sourceURL = URL(string: "https://example.com/soup")!
private let schemaFixture = """
{"@graph":[{"@type":"WebPage","name":"Page"},{"@type":["Recipe"],"name":"Soup &amp; toast",
"author":{"name":"Cook"},"prepTime":"PT5M","cookTime":"PT15M","recipeIngredient":["1 onion","2 tomatoes"],
"recipeInstructions":[{"@type":"HowToSection","name":"Soup","itemListElement":[{"@type":"HowToStep","text":"Simmer for 15 minutes."}]}],
"aggregateRating":{"ratingValue":"4.5","ratingCount":"12"},
"review":[{"reviewBody":"Lovely &amp; simple","reviewRating":{"ratingValue":5}}]}]}
"""

private final class StructuredImportClient: NetworkClient, @unchecked Sendable {
    let dto: RecipeDTO
    private let lock = NSLock()
    private var postedPaths: [String] = []
    var paths: [String] { lock.withLock { postedPaths } }
    init(dto: RecipeDTO) { self.dto = dto }
    func get<Entity: Decodable>(_ endpoint: any Endpoint) async throws -> Entity { throw TestError.unexpectedRequest }
    func getExpect200(_ endpoint: any Endpoint) async throws -> Bool { false }
    func put<Entity: Decodable>(_ endpoint: any Endpoint) async throws -> Entity { throw TestError.unexpectedRequest }
    func post<Entity: Decodable>(_ endpoint: any Endpoint) async throws -> Entity {
        lock.withLock { postedPaths.append(endpoint.path()) }
        return dto as! Entity
    }
    func delete(_ endpoint: any Endpoint) async throws -> Bool { false }
    private enum TestError: Error { case unexpectedRequest }
}
