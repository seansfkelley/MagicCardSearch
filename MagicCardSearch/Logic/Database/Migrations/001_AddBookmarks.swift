//
//  001_AddBookmarks.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-02.
//
import GRDB

func migrate_001_AddBookmarks(db: Database) throws {
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
