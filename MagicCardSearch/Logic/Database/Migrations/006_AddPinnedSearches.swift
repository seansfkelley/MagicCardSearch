import GRDB

func migrate_006_AddPinnedSearches(db: Database) throws {
    try db.create(table: "pinnedSearchEntries") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("pinnedAt", .datetime).notNull()
        t.column("filters", .jsonText).notNull().unique(onConflict: .replace)
    }
}
