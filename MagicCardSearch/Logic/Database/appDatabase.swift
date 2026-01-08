import OSLog
import SQLiteData

private let logger = Logger(subsystem: "MagicCardSearch", category: "appDatabase")

func appDatabase() throws -> any DatabaseWriter {
    @Dependency(\.context) var context
    var configuration = Configuration()
    #if DEBUG
        configuration.prepareDatabase { db in
            db.trace(options: .profile) {
                if context == .preview {
                    print("\($0.expandedDescription)")
                } else {
                    logger.debug("\($0.expandedDescription)")
                }
            }
        }
    #endif
    let database = try defaultDatabase(configuration: configuration)
    logger.info("opened database path=\(database.path)")
    var migrator = DatabaseMigrator()
    #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
    #endif
    for (name, migration) in orderedMigrations {
        migrator.registerMigration(name, migrate: migration)
    }
    try migrator.migrate(database)
    return database
}
