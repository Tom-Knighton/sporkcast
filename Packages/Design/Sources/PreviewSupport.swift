import Dependencies
import Persistence

public enum PreviewSupport {

    @discardableResult
    public static func preparePreviewDatabase(
        tracer: (@Sendable (String) -> Void)? = { @Sendable in print($0) },
        seed: ((any DatabaseWriter) throws -> Void)? = nil
    ) -> any DatabaseWriter {
        let database = try! AppDatabaseFactory.makeAppDatabase(tracer: tracer)

        prepareDependencies {
            $0.defaultDatabase = database

            if let seed {
                try? seed(database)
            }
        }

        return database
    }
}
