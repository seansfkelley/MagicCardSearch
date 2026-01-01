//
//  PinnedFilterStore.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import SQLite
import Foundation

struct PinnedFilterStore {
    struct Row: Codable {
        let id: Int
        let pinnedAt: Date
        let filter: SearchFilter

        enum CodingKeys: String, CodingKey {
            case id
            case pinnedAt = "pinned_at"
            case filter
        }
    }

    private let db: Connection
    private let table = Table("pinned_filters")

    private let id = Expression<Int>("id")
    private let pinnedAt = Expression<Date>("pinned_at")
    private let filter = Expression<String>("filter")

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

    func pin(_ searchFilter: SearchFilter, at date: Date = Date()) throws {
        let filterString = String(data: try Self.encoder.encode(searchFilter), encoding: .utf8)!
        try db.run(
            table.insert(
                or: .ignore,
                filter <- filterString,
                pinnedAt <- date
            )
        )
    }

    func unpin(_ searchFilter: SearchFilter) throws {
        let filterString = String(data: try Self.encoder.encode(searchFilter), encoding: .utf8)!
        try db.run(table.filter(filter == filterString).delete())
    }

    var allPinnedFiltersChronologically: [Row] {
        get throws {
            try db.prepareRowIterator(table.order(pinnedAt.desc)).map { try $0.decode() }
        }
    }

    internal func test_getAll() throws -> [Row] {
        try db.prepareRowIterator(table).map { try $0.decode() }
    }
}
