import Dependencies
import Persistence
import SQLiteData

public enum PreviewSupport {

    @discardableResult
    public static func preparePreviewDatabase(
        tracer: ((String) -> Void)? = { print($0) },
        seed: ((any DatabaseWriter) throws -> Void)? = nil
    ) -> any DatabaseWriter {
        let database = try! AppDatabaseFactory.makeAppDatabase(tracer: tracer)

        if let seed {
            try? seed(database)
        }

        prepareDependencies {
            $0.defaultDatabase = database
            $0.defaultSyncEngine = try! SyncEngine(
                for: database,
                tables: DBHome.self,
                DBRecipe.self,
                DBRecipeIngredientGroup.self,
                DBRecipeIngredient.self,
                DBRecipeStepGroup.self,
                DBRecipeStep.self,
                DBRecipeStepTiming.self,
                DBRecipeStepTemperature.self,
                DBRecipeImage.self
            )
        }

        return database
    }
}
