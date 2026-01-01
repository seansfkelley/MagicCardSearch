//
//  Migration.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//
import SQLite

protocol DatabaseMigration: Sendable {
    var version: Int32 { get }
    func migrate(db: Connection) throws
}

let orderedMigrations: [DatabaseMigration] = [
    Migrate20251229Initial(),
    Migrate20251231AddBookmarks(),
]
