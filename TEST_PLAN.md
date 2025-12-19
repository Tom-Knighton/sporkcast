# Test Plan

## Goals
- Cover core domain utilities that transform or interpret data (dates, persistence bridging, and view model side effects).
- Exercise database wiring built on SQLiteData to ensure migrations and CRUD helpers behave in isolation.
- Provide lightweight UI-facing validation by checking view model behaviour that updates persisted state.

## Planned Test Cases
1. **Date utilities** – verify `Date.lastMonday` always returns the prior Monday even when the current day is Monday.
2. **Persistence seeding** – confirm `AppDatabaseFactory.makeAppDatabase` produces a migrated database that accepts inserts and reads for `DBMealplanEntry`.
3. **Mealplan domain bridging** – ensure `FullDBMealplanEntry.toDomainModel()` returns entries with attached recipe summaries and preserves ordering/indexes.
4. **Recipe view model styling hook** – ensure `RecipeViewModel.setDominantColour` updates both in-memory state and the backing database value.

## Evaluation
- The tests focus on pure logic and database wiring, avoiding network or CloudKit dependencies so they remain deterministic.
- Coverage concentrates on components used across multiple views (date helpers, persistence factories, domain mappers, and UI-facing view models), providing practical regression protection for existing functionality.
- Additional UI snapshot or interaction testing would require a simulator/runtime not available in this environment; the chosen cases maximise relevance without external services.
