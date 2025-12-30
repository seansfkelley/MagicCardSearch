//
//  FilterHistory.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-29.
//
import SQLite
import Foundation

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

    private static let defaultMaxAgeInDays = 90

    internal init(db: Connection) {
        self.db = db
    }

    func recordUsage(of searchFilter: SearchFilter, at date: Date = Date()) throws {
        let filterString = String(data: try JSONEncoder().encode(searchFilter), encoding: .utf8)!
        
        try db.run(
            table.upsert(
                lastUsedAt <- date,
                filter <- filterString,
                onConflictOf: filter,
            ),
        )
    }

    func deleteUsage(of searchFilter: SearchFilter) throws {
        let filterString = String(data: try JSONEncoder().encode(searchFilter), encoding: .utf8)!
        
        try db.run(table.filter(filter == filterString).delete())
    }

    var allFiltersChronologically: [Row] {
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
                DELETE FROM filter_history
                WHERE id NOT IN (
                    SELECT id FROM filter_history
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
