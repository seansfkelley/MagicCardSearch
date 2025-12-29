//
//  SQLiteDatabase.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//
import SQLite
import Foundation

actor SQLiteDatabase {
    private let db: Connection

    private init(db: Connection) {
        self.db = db
    }

    var userVersion: Int32? {
        db.userVersion
    }

    public static func initialize(path: String = "MagicCardSearch.sqlite3") async throws -> SQLiteDatabase {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let dbPath = documentsPath.appendingPathComponent(path).path

        let db = SQLiteDatabase(db: try Connection(dbPath))
        try await db.applyMigrations()
        return db
    }

    public static func initializeTest() async throws -> SQLiteDatabase {
        let db = SQLiteDatabase(db: try Connection(.inMemory))
        try await db.applyMigrations()
        return db
    }

    fileprivate func applyMigrations() throws {
        let index = Int(db.userVersion ?? 0)
        for migration in orderedMigrations[index...] {
            try db.transaction {
                try migration.migrate(db: db)
                db.userVersion = migration.version
            }
        }
    }
}

struct FilterHistoryRow: Codable {
    let id: Int
    let lastUsedAt: Date
    let filter: SearchFilter
}
