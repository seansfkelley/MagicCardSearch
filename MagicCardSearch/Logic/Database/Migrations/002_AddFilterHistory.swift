import GRDB

func migrate_002_AddFilterHistory(db: Database) throws {
    try db.create(table: "filterHistoryEntries") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("lastUsedAt", .datetime).notNull()
        t.column("filter", .jsonText).notNull().unique(onConflict: .replace)
    }
}
