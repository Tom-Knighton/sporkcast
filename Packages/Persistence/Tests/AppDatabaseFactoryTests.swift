import Testing
@testable import Persistence

@Test func makeAppDatabaseSupportsMigrations() async throws {
    let database = try AppDatabaseFactory.makeAppDatabase()

    let entry = DBMealplanEntry(
        id: UUID(),
        date: .now,
        index: 0,
        noteText: "Preview entry",
        recipeId: nil
    )

    try await database.write { db in
        try DBMealplanEntry.insert { entry }.execute(db)
    }

    let fetched = try await database.read { db in
        try DBMealplanEntry.select().fetchAll(db)
    }

    #expect(!fetched.isEmpty)
    #expect(fetched.first?.noteText == entry.noteText)
}
