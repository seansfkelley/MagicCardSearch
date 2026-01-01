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
        let bookmarks = Table("bookmarks")

        let id = Expression<UUID>("id")
        let name = Expression<String>("name")
        let typeLine = Expression<String?>("type_line")
        let smallImageUrl = Expression<String?>("small_image_url")
        let setCode = Expression<String>("set_code")
        let setName = Expression<String>("set_name")
        let collectorNumber = Expression<String>("collector_number")
        let releasedAt = Expression<Date?>("released_at")
        let bookmarkedAt = Expression<Date>("bookmarked_at")

        try db.run(bookmarks.create(ifNotExists: true) { table in
            table.column(id, primaryKey: true)
            table.column(name)
            table.column(typeLine)
            table.column(smallImageUrl)
            table.column(setCode)
            table.column(setName)
            table.column(collectorNumber)
            table.column(releasedAt)
            table.column(bookmarkedAt)
        })
    }
}
