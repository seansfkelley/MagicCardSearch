//
//  SQLiteDatabase.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//
import SQLite
import Foundation

struct SQLiteDatabase {
    private let db: Connection
    public let filterHistory: FilterHistory

    private init(db: Connection) {
        self.db = db
        self.filterHistory = .init(db: db)
    }

    var userVersion: Int32? { db.userVersion }

    public static func initialize(path: String = "MagicCardSearch.sqlite3") throws -> SQLiteDatabase {
        let documentsPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dbPath = documentsPath.appendingPathComponent(path).path

        let db = SQLiteDatabase(db: try Connection(dbPath))
        try db.applyMigrations()
        return db
    }

    public static func initializeTest() throws -> SQLiteDatabase {
        let db = SQLiteDatabase(db: try Connection(.inMemory))
        try db.applyMigrations()
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

struct FilterHistory {
    struct Row: Codable {
        let id: Int
        let lastUsedAt: Date
        let filter: SearchFilter
        
        enum CodingKeys: String, CodingKey {
            case id
            case lastUsedAt = "last_used_at"
            case filter
        }
    }

    private let db: Connection
    private let table = Table("filter_history")

    private let id = Expression<Int>("id")
    private let lastUsedAt = Expression<Date>("last_used_at")
    private let filter = Expression<String>("filter")

    fileprivate init(db: Connection) {
        self.db = db
    }

    func recordUsage(of searchFilter: SearchFilter) throws {
        let filterString = String(data: try JSONEncoder().encode(searchFilter), encoding: .utf8)!
        
        try db.run(table.upsert(
            lastUsedAt <- Date(),
            filter <- filterString,
            onConflictOf: filter
        ))
    }

    internal func test_getAll() throws -> [Row] {
        try db.prepare(table).map { try $0.decode() }
    }
}
