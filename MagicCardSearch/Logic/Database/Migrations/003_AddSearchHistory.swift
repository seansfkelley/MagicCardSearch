//
//  001_AddBookmarks.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-02.
//
import GRDB

func migrate_003_AddSearchHistory(db: Database) throws {
    try db.create(table: "searchHistoryEntries") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("lastUsedAt", .datetime).notNull()
        t.column("filters", .jsonText).notNull().unique(onConflict: .replace)
    }
}
