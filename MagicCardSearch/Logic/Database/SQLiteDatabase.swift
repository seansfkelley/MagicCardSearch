//
//  SQLiteDatabase2.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-01.
//
import OSLog
import SQLiteData

private let logger = Logger(subsystem: "MagicCardApp", category: "Database")

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
    logger.info("open '\(database.path)'")
    var migrator = DatabaseMigrator()
    #if DEBUG
        migrator.eraseDatabaseOnSchemaChange = true
    #endif
    migrator.registerMigration("add bookmarks") { db in
        try db.create(table: "bookmarkedCards") { t in
            t.column("id", .text).notNull(onConflict: .replace)
            t.column("name", .text).notNull()
            t.column("typeLine", .text)
            t.column("frontCardFace", .jsonText).notNull()
            t.column("backCardFace", .jsonText)
            t.column("setCode", .text).notNull()
            t.column("setName", .text).notNull()
            t.column("collectorNumber", .text).notNull()
            t.column("releasedAt", .datetime).notNull()
            t.column("bookmarkedAt", .datetime).notNull()
        }
    }
    migrator.registerMigration("add filter history") { db in
        try db.create(table: "filterHistoryEntries") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("lastUsedAt", .datetime).notNull()
            t.column("filter", .jsonText).notNull().unique(onConflict: .replace)
        }
    }
    migrator.registerMigration("add search history") { db in
        try db.create(table: "searchHistoryEntries") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("lastUsedAt", .datetime).notNull()
            t.column("filters", .jsonText).notNull().unique(onConflict: .replace)
        }
    }
    migrator.registerMigration("add pinned filters") { db in
        try db.create(table: "pinnedFilterEntries") { t in
            t.autoIncrementedPrimaryKey("id")
            t.column("pinnedAt", .datetime).notNull()
            t.column("filter", .jsonText).notNull().unique(onConflict: .replace)
        }
    }
    try migrator.migrate(database)
    return database
}
