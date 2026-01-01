//
//  SQLiteDatabase.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//
import SQLite
import Foundation

struct SQLiteDatabase {
    enum Location {
        case memory
        case filename(String)
        case path(String)
    }

    private let connection: Connection
    public let searchHistory: SearchHistoryStore
    public let pinnedFilters: PinnedFilterStore

    private init(_ connection: Connection) {
        self.connection = connection
        self.searchHistory = .init(db: connection)
        self.pinnedFilters = .init(db: connection)
    }

    var userVersion: Int32? { connection.userVersion }

    public static func initialize(_ location: Location = .memory) throws -> SQLiteDatabase {
        let connection = switch location {
        case .memory:
            try Connection(.inMemory)
        case .filename(let filename):
            try {
                let documentsPath = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
                let path = documentsPath.appendingPathComponent(filename).path
                let connection = try Connection(path)
                try executeFileBackedPragmas(connection)
                return connection
            }()
        case .path(let path):
            try {
                let connection = try Connection(path)
                try executeFileBackedPragmas(connection)
                return connection
            }()
        }

        let db = SQLiteDatabase(connection)
        try db.applyMigrations()
        return db
    }

    private static func executeFileBackedPragmas(_ connection: Connection) throws {
        // Aggressively keep things in memory so I can avoid writing my own memory caching and just bang on SQLite.
        try connection.execute("PRAGMA temp_store = MEMORY;")
        try connection.execute("PRAGMA cache_size = -20000;")
        try connection.execute("PRAGMA mmap_size  = 268435456;")
    }

    fileprivate func applyMigrations() throws {
        let index = Int(connection.userVersion ?? 0)
        for migration in orderedMigrations[index...] {
            try connection.transaction {
                try migration.migrate(db: connection)
                connection.userVersion = migration.version
            }
        }
    }
}
