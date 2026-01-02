//
//  001_AddBookmarks.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-02.
//
import GRDB

func migrate_004_AddPinnedFilters(db: Database) throws {
    try db.create(table: "pinnedFilterEntries") { t in
        t.autoIncrementedPrimaryKey("id")
        t.column("pinnedAt", .datetime).notNull()
        t.column("filter", .jsonText).notNull().unique(onConflict: .replace)
    }
}
