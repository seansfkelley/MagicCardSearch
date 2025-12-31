//
//  SearchHistoryStore.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import SQLite
import Foundation

struct SearchHistoryStore {
    struct Row: Codable {
        let id: Int
        let lastUsedAt: Date
        let search: [SearchFilter]

        enum CodingKeys: String, CodingKey {
            case id
            case lastUsedAt = "last_used_at"
            case search
        }
    }

    private let db: Connection
    private let table = Table("search_history")

    private let id = Expression<Int>("id")
    private let lastUsedAt = Expression<Date>("last_used_at")
    private let search = Expression<String>("search")

    private static let defaultMaxAgeInDays = 90

    private static let encoder = {
        let encoder = JSONEncoder()
        // FIXME: Unique'ing on the JSON column is super fragile. Tests used to flake without this
        // line, and it would only take one case of accidentally relying on SQLite.swift's
        // auto-serialization of Codable types, which would not use this encoder, to insert duplicates.
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }()

    internal init(db: Connection) {
        self.db = db
    }

    func recordSearch(with filters: [SearchFilter], at date: Date = Date()) throws {
        let searchString = String(data: try Self.encoder.encode(filters), encoding: .utf8)!

        try db.run(
            table.upsert(
                lastUsedAt <- date,
                search <- searchString,
                onConflictOf: search,
            ),
        )
    }

    func deleteSearch(with filters: [SearchFilter]) throws {
        let searchString = String(data: try Self.encoder.encode(filters), encoding: .utf8)!

        try db.run(table.filter(search == searchString).delete())
    }

    var allSearchesChronologically: [Row] {
        get throws {
            try db.prepareRowIterator(table.order(lastUsedAt.desc)).map { try $0.decode() }
        }
    }

    func garbageCollect(
        hardLimit: Int = 1000,
        softLimit: Int = 500,
        cutoffDate: Date = Date().addingTimeInterval(TimeInterval(-Self.defaultMaxAgeInDays * 24 * 60 * 60)),
    ) throws {
        try db.run(table.filter(lastUsedAt < cutoffDate).delete())

        let count = try db.scalar(table.count)
        if count > hardLimit {
            // Can't do NOT IN with the query builder, alas.
            let sql = """
                DELETE FROM search_history
                WHERE id NOT IN (
                    SELECT id FROM search_history
                    ORDER BY last_used_at DESC
                    LIMIT ?
                )
                """
            try db.run(sql, softLimit)
        }
    }

    internal func test_getAll() throws -> [Row] {
        try db.prepareRowIterator(table).map { try $0.decode() }
    }
}
