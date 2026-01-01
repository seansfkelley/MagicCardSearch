//
//  Migrate20251231AddBookmarks.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import Foundation
import SQLite

struct Migrate20251231AddBookmarks: DatabaseMigration {
    let version: Int32 = 2

    func migrate(db: Connection) throws {
        let filterHistory = Table("bookmarks")
        do {
            let id = Expression<Int>("id")

            try db.run(filterHistory.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
            })
        }
    }
}
