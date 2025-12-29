//
//  1.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//
import Foundation
import SQLite

struct Migrate20251229Initial: DatabaseMigration {
    let version: Int32 = 1

    func migrate(db: Connection) throws {
        let filterHistory = Table("filter_history")
        do {
            let id = Expression<Int>("id")
            let lastUsedAt = Expression<Date>("last_used_at")
            let filter = Expression<String>("filter")

            try db.run(filterHistory.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(lastUsedAt, defaultValue: Date())
                table.column(filter)
            })
        }

        let searchHistory = Table("search_history")
        do {
            let id = Expression<Int>("id")
            let lastUsedAt = Expression<Date>("last_used_at")
            let search = Expression<String>("search")

            try db.run(searchHistory.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(lastUsedAt, defaultValue: Date())
                table.column(search)
            })
        }

        let pinnedFilters = Table("pinned_filters")
        do {
            let id = Expression<Int>("id")
            let pinnedAt = Expression<Date>("pinned_at")
            let filter = Expression<String>("filter")

            try db.run(pinnedFilters.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(pinnedAt, defaultValue: Date())
                table.column(filter)
            })
        }

        let pinnedSearches = Table("pinned_searches")
        do {
            let id = Expression<Int>("id")
            let pinnedAt = Expression<Date>("pinned_at")
            let search = Expression<String>("search")

            try db.run(pinnedFilters.create(ifNotExists: true) { table in
                table.column(id, primaryKey: .autoincrement)
                table.column(pinnedAt, defaultValue: Date())
                table.column(search)
            })
        }
    }
}
