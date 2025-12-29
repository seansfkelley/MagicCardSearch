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

    internal init(db: Connection) {
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
