import Testing
import Foundation
import ZIPFoundation
import API
import Models
@testable import RecipeImporting

@Test func markdownParserExtractsIngredientsAndSteps() {
    let markdown = """
    # Lemon Pasta

    ## Ingredients
    - 200g spaghetti
    - 1 lemon

    ## Method
    1. Boil pasta
    2. Toss with lemon
    """

    let records = MarkdownRecipeParser().parse(markdown)

    #expect(records.count == 1)
    #expect(records[0].title == "Lemon Pasta")
    #expect(records[0].ingredientSections.flatMap(\.ingredients).count == 2)
    #expect(records[0].stepSections.flatMap(\.steps).count >= 2)
}

@Test func syntheticSourceURLIsNonWeb() {
    let synthetic = SyntheticSourceURL.make(mode: .markdown, vendor: .markdown, seed: "sample")

    #expect(synthetic.hasPrefix("sporkcast://import/"))
    #expect(SyntheticSourceURL.isExternalWebURL(synthetic) == false)
    #expect(SyntheticSourceURL.isExternalWebURL("https://example.com") == true)
}

@Test func duplicateDetectionFindsStrongMatch() async {
    let candidateRecipe = makeRecipe(
        title: "Tomato Soup",
        ingredients: ["2 tomatoes", "1 onion"],
        steps: ["Cook tomatoes", "Blend"]
    )

    let existingRecipe = makeRecipe(
        title: "Tomato Soup",
        ingredients: ["tomatoes", "onion", "salt"],
        steps: ["Simmer", "Blend"]
    )

    let candidate = RecipeImportCandidate(
        recipe: candidateRecipe,
        provenance: .init(mode: .markdown, vendor: .markdown, sourceHint: nil),
        quality: .evaluate(recipe: candidateRecipe),
        usedAPIFallback: false,
        rawTextForFallback: "Tomato Soup"
    )

    let client = RecordingClient()
    let coordinator = RecipeImportCoordinator(client: client)

    let matches = coordinator.detectDuplicates(for: [candidate], existing: [existingRecipe])

    #expect(matches[candidate.id] != nil)
}

@Test func lowConfidenceImportTriggersTextFallbackEndpoint() async throws {
    let client = RecordingClient()
    let coordinator = RecipeImportCoordinator(client: client)

    _ = try await coordinator.prepareImport(from: .ocrText("# Recipe\n- 1 egg"), homeId: nil)

    let paths = await client.paths()
    #expect(paths.contains("Parser/ParseText"))
}

@Test func webURLImportPreservesRatingsAndComments() async throws {
    let client = RecordingClient()
    let coordinator = RecipeImportCoordinator(client: client)

    let sourceURL = try #require(URL(string: "https://example.com/chicken-katsu-curry"))
    let result = try await coordinator.prepareImport(from: .webURL(sourceURL), homeId: nil)

    #expect(result.candidates.count == 1)

    let ratingInfo = result.candidates[0].recipe.ratingInfo
    #expect(ratingInfo != nil)
    #expect(ratingInfo?.overallRating != nil)
    #expect((ratingInfo?.totalRatings ?? 0) > 0)
    #expect((ratingInfo?.ratings.count ?? 0) > 0)
    #expect(ratingInfo?.ratings.contains(where: { ($0.comment?.isEmpty == false) }) == true)
}

@Test func pestleExtensionParsesWithPestleVendor() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("sample.pestle")
    let payload = """
    {
      "title": "Pesto Pasta",
      "ingredients": ["200g pasta", "2 tbsp pesto"],
      "instructions": ["Boil pasta", "Stir in pesto"]
    }
    """
    try payload.write(to: fileURL, atomically: true, encoding: .utf8)

    let parser = RecipeImportFileParser()
    let parsed = try parser.parse(fileURL: fileURL)

    #expect(parsed.count == 1)
    #expect(parsed[0].record.title == "Pesto Pasta")
    #expect(parsed[0].provenance.vendor == .pestle)
}

@Test func vendorHintFromSourceSelectionIsAppliedForJSONImports() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("export.json")
    let payload = """
    {
      "name": "Tomato Soup",
      "ingredients": "2 tomatoes\\n1 onion",
      "directions": "Cook\\nBlend"
    }
    """
    try payload.write(to: fileURL, atomically: true, encoding: .utf8)

    let parser = RecipeImportFileParser()
    let parsed = try parser.parse(fileURL: fileURL, vendorHint: .paprika)

    #expect(parsed.count == 1)
    #expect(parsed[0].provenance.vendor == .paprika)
}

@Test func croutonCrumbFileParsesWithCroutonVendor() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("sample.crumb")
    let payload = """
    {
      "name": "Chicken Katsu Curry",
      "sourceName": "beatthebudget.com",
      "webLink": "https://beatthebudget.com/recipe/chicken-katsu-curry/",
      "sourceImage": "iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO7Y3ioAAAAASUVORK5CYII=",
      "serves": 6,
      "duration": 5,
      "cookingDuration": 30,
      "ingredients": [
        {
          "quantity": { "amount": 650, "quantityType": "GRAMS" },
          "ingredient": { "name": "chicken breasts" }
        },
        {
          "quantity": { "amount": 2, "quantityType": "ITEM" },
          "ingredient": { "name": "egg" }
        }
      ],
      "steps": [
        { "step": "PREHEAT OVEN TO 200°C", "isSection": true },
        { "step": "Cook the sauce.", "isSection": false }
      ]
    }
    """
    try payload.write(to: fileURL, atomically: true, encoding: .utf8)

    let parser = RecipeImportFileParser()
    let parsed = try parser.parse(fileURL: fileURL)

    #expect(parsed.count == 1)
    let record = parsed[0].record
    #expect(parsed[0].provenance.vendor == .crouton)
    #expect(record.title == "Chicken Katsu Curry")
    #expect(record.author == "beatthebudget.com")
    #expect(record.sourceURL == "https://beatthebudget.com/recipe/chicken-katsu-curry/")
    #expect(record.serves == "6")
    #expect(record.prepMinutes == 5)
    #expect(record.cookMinutes == 30)
    #expect(record.imageData != nil)
    #expect(record.imageURL == nil)
    let ingredientLines = record.ingredientSections.flatMap(\.ingredients)
    #expect(ingredientLines.first?.hasPrefix("650 g") == true)
    #expect(ingredientLines.contains(where: { $0 == "2 egg" || $0 == "2 eggs" }))
    #expect(record.stepSections.flatMap(\.steps).count == 2)
}

@Test func croutonZipWithCrumbEntriesParsesRecipes() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let zipURL = tempDirectory.appendingPathComponent("Crouton Recipes.zip")
    let payload = """
    {
      "name": "Chocolate Chip Cookies",
      "ingredients": [
        {
          "quantity": { "amount": 250, "quantityType": "MILLS" },
          "ingredient": { "name": "milk" }
        }
      ],
      "steps": [
        { "step": "Preheat oven." },
        { "step": "Bake until golden." }
      ]
    }
    """

    try createArchive(
        at: zipURL,
        entries: [
            ("Chocolate Chip Cookies-1.crumb", payload),
            ("README.txt", "ignored")
        ]
    )

    let parser = RecipeImportFileParser()
    let parsed = try parser.parse(fileURL: zipURL, vendorHint: .crouton)

    #expect(parsed.count == 1)
    #expect(parsed[0].provenance.vendor == .crouton)
    #expect(parsed[0].record.title == "Chocolate Chip Cookies")
    #expect(parsed[0].record.ingredientSections.flatMap(\.ingredients).count == 1)
    #expect(parsed[0].record.ingredientSections.flatMap(\.ingredients).first?.hasPrefix("250 ml") == true)
    #expect(parsed[0].record.stepSections.flatMap(\.steps).count == 2)
}

@Test func sporkcastZipWithSporkastEntriesParsesRecipes() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let zipURL = tempDirectory.appendingPathComponent("Sporkast Export.zip")
    let payload = """
    {
      "schemaVersion": 1,
      "exportFormat": "sporkast",
      "exportedAt": "2026-04-04T09:00:00Z",
      "recipe": {
        "id": "bfb145f8-f4df-45d8-8f2f-b2c7ea7b4e33",
        "title": "Garlic Mushrooms",
        "description": "Quick side dish",
        "author": "Spork Tester",
        "sourceUrl": "https://example.com/garlic-mushrooms",
        "minutesToPrepare": 5,
        "minutesToCook": 10,
        "totalMins": 15,
        "serves": "2",
        "overallRating": 4.8,
        "totalRatings": 2,
        "summarisedRating": "Loved by most cooks"
      },
      "image": {
        "recipeId": "bfb145f8-f4df-45d8-8f2f-b2c7ea7b4e33",
        "imageSourceUrl": "https://example.com/mushrooms.jpg",
        "imageData": null
      },
      "ingredientGroups": [
        {
          "id": "5038ec2f-208a-4f6b-a872-e35534c22df8",
          "recipeId": "bfb145f8-f4df-45d8-8f2f-b2c7ea7b4e33",
          "title": "Ingredients",
          "sortIndex": 0
        }
      ],
      "ingredients": [
        {
          "id": "349c3750-c7ab-4ca9-899f-e32d95ea5a5d",
          "ingredientGroupId": "5038ec2f-208a-4f6b-a872-e35534c22df8",
          "sortIndex": 0,
          "rawIngredient": "300g mushrooms"
        },
        {
          "id": "2f988c12-6547-4228-90b8-0d0b92f7ee55",
          "ingredientGroupId": "5038ec2f-208a-4f6b-a872-e35534c22df8",
          "sortIndex": 1,
          "rawIngredient": "2 cloves garlic"
        }
      ],
      "stepGroups": [
        {
          "id": "5ec3ad8f-8cd6-46d6-9666-c495dc4c8ef9",
          "recipeId": "bfb145f8-f4df-45d8-8f2f-b2c7ea7b4e33",
          "title": "Method",
          "sortIndex": 0
        }
      ],
      "steps": [
        {
          "id": "a8de03cb-c7ca-4be6-9687-22ea590d997f",
          "groupId": "5ec3ad8f-8cd6-46d6-9666-c495dc4c8ef9",
          "sortIndex": 0,
          "instruction": "Saute mushrooms."
        },
        {
          "id": "da39ea53-4d63-4949-ad4c-16f30f2ce93e",
          "groupId": "5ec3ad8f-8cd6-46d6-9666-c495dc4c8ef9",
          "sortIndex": 1,
          "instruction": "Add garlic and finish."
        }
      ],
      "stepTimings": [],
      "stepTemperatures": [],
      "ratings": [
        {
          "id": "f2f53baf-4f48-4b57-9678-48194ec9f862",
          "recipeId": "bfb145f8-f4df-45d8-8f2f-b2c7ea7b4e33",
          "rating": 5,
          "comment": "Great weeknight side"
        }
      ],
      "stepLinkedIngredients": []
    }
    """

    try createArchive(
        at: zipURL,
        entries: [
            ("001-garlic-mushrooms-bfb145f8.sporkast", payload)
        ]
    )

    let parser = RecipeImportFileParser()
    let parsed = try parser.parse(fileURL: zipURL, vendorHint: .sporkcast)

    #expect(parsed.count == 1)
    #expect(parsed[0].provenance.vendor == .sporkcast)
    #expect(parsed[0].record.title == "Garlic Mushrooms")
    #expect(parsed[0].record.author == "Spork Tester")
    #expect(parsed[0].record.sourceURL == "https://example.com/garlic-mushrooms")
    #expect(parsed[0].record.serves == "2")
    #expect(parsed[0].record.prepMinutes == 5)
    #expect(parsed[0].record.cookMinutes == 10)
    #expect(parsed[0].record.totalMinutes == 15)
    #expect(parsed[0].record.overallRating == 4.8)
    #expect(parsed[0].record.totalRatings == 2)
    #expect(parsed[0].record.summarisedRating == "Loved by most cooks")
    #expect(parsed[0].record.ratings.count == 1)
    #expect(parsed[0].record.ratings[0].rating == 5)
    #expect(parsed[0].record.ratings[0].comment == "Great weeknight side")
    #expect(parsed[0].record.ingredientSections.flatMap(\.ingredients) == ["300g mushrooms", "2 cloves garlic"])
    #expect(parsed[0].record.stepSections.flatMap(\.steps) == ["Saute mushrooms.", "Add garlic and finish."])
}

@Test func pestleSchemaMapsIngredientsStepsImageAndAuthor() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("schema.pestle")
    let payload = """
    [
      {
        "name": "Skillet Eggs",
        "description": "Quick breakfast",
        "author": { "name": "Chef Sam" },
        "source": "https://example.com/skillet-eggs",
        "image": [{ "url": "https://example.com/eggs.jpg" }],
        "recipeYield": "2",
        "prepTime": "PT15M",
        "cookTime": "PT10M",
        "totalTime": "PT25M",
        "recipeIngredient": [
          { "text": "2 eggs" },
          { "quantity": 1, "unit": "tbsp", "name": "butter" }
        ],
        "recipeInstructions": [
          { "text": "Melt butter." },
          { "name": "Cook eggs to preference." }
        ]
      }
    ]
    """
    try payload.write(to: fileURL, atomically: true, encoding: .utf8)

    let parser = RecipeImportFileParser()
    let parsed = try parser.parse(fileURL: fileURL)

    #expect(parsed.count == 1)
    let record = parsed[0].record
    #expect(record.title == "Skillet Eggs")
    #expect(record.author == "Chef Sam")
    #expect(record.imageURL == "https://example.com/eggs.jpg")
    #expect(record.serves == "2")
    #expect(record.prepMinutes == 15)
    #expect(record.cookMinutes == 10)
    #expect(record.totalMinutes == 25)
    #expect(record.ingredientSections.flatMap(\.ingredients).count == 2)
    #expect(record.stepSections.flatMap(\.steps).count == 2)
}

@Test func pestleISO8601HoursAndMinutesAreConvertedToMinutes() throws {
    let tempDirectory = FileManager.default.temporaryDirectory
        .appendingPathComponent(UUID().uuidString, isDirectory: true)
    try FileManager.default.createDirectory(at: tempDirectory, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempDirectory) }

    let fileURL = tempDirectory.appendingPathComponent("durations.pestle")
    let payload = """
    [
      {
        "name": "Long Braise",
        "prepTime": "PT1H30M",
        "cookTime": "PT2H",
        "totalTime": "PT3H30M",
        "recipeIngredient": [{ "text": "1kg beef" }],
        "recipeInstructions": [{ "text": "Braise slowly." }]
      }
    ]
    """
    try payload.write(to: fileURL, atomically: true, encoding: .utf8)

    let parser = RecipeImportFileParser()
    let parsed = try parser.parse(fileURL: fileURL)

    #expect(parsed.count == 1)
    let record = parsed[0].record
    #expect(record.prepMinutes == 90)
    #expect(record.cookMinutes == 120)
    #expect(record.totalMinutes == 210)
}

private final class RecordingClient: NetworkClient, @unchecked Sendable {
    private var postedPaths: [String] = []

    func get<Entity: Decodable>(_ endpoint: any Endpoint) async throws -> Entity {
        endpoint.mockResponseOk() as! Entity
    }

    func getExpect200(_ endpoint: Endpoint) async throws -> Bool {
        true
    }

    func put<Entity: Decodable>(_ endpoint: Endpoint) async throws -> Entity {
        endpoint.mockResponseOk() as! Entity
    }

    func post<Entity: Decodable>(_ endpoint: Endpoint) async throws -> Entity {
        postedPaths.append(endpoint.path())
        return endpoint.mockResponseOk() as! Entity
    }

    func delete(_ endpoint: Endpoint) async throws -> Bool {
        true
    }

    func paths() -> [String] {
        postedPaths
    }
}

private func makeRecipe(title: String, ingredients: [String], steps: [String]) -> Recipe {
    let now = Date()
    let ingredientModels = ingredients.enumerated().map { index, text in
        RecipeIngredient(
            id: UUID(),
            sortIndex: index,
            ingredientText: text,
            ingredientPart: text,
            extraInformation: nil,
            quantity: nil,
            unit: nil,
            emoji: nil,
            owned: false
        )
    }

    let stepModels = steps.enumerated().map { index, text in
        RecipeStep(
            id: UUID(),
            sortIndex: index,
            instructionText: text,
            timings: [],
            temperatures: [],
            linkedIngredients: []
        )
    }

    return Recipe(
        id: UUID(),
        title: title,
        description: nil,
        summarisedTip: nil,
        author: nil,
        sourceUrl: "sporkcast://import/markdown/markdown/test",
        image: .init(imageThumbnailData: nil, imageUrl: nil),
        timing: .init(totalTime: nil, prepTime: nil, cookTime: nil),
        serves: nil,
        ratingInfo: nil,
        dateAdded: now,
        dateModified: now,
        ingredientSections: [
            .init(id: UUID(), title: "Ingredients", sortIndex: 0, ingredients: ingredientModels)
        ],
        stepSections: [
            .init(id: UUID(), sortIndex: 0, title: "Method", steps: stepModels)
        ],
        dominantColorHex: nil,
        homeId: nil
    )
}

private func createArchive(at url: URL, entries: [(String, String)]) throws {
    let archive = try Archive(url: url, accessMode: .create)

    for (path, contents) in entries {
        let data = Data(contents.utf8)
        try archive.addEntry(
            with: path,
            type: .file,
            uncompressedSize: Int64(data.count),
            compressionMethod: .deflate,
            provider: { position, size in
                let lowerBound = Int(position)
                let upperBound = min(lowerBound + size, data.count)
                return data.subdata(in: lowerBound ..< upperBound)
            }
        )
    }
}
