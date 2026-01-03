//
//  005_AddBlobStore.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-02.
//
import GRDB

func migrate_005_AddBlobStore(db: Database) throws {
    try db.create(table: "blobEntries") { t in
        t.column("key", .text).notNull().primaryKey(onConflict: .replace)
        t.column("value", .blob).notNull()
        t.column("insertedAt", .datetime).notNull()
    }
}

