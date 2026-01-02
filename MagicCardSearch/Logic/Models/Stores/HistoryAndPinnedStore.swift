//
//  HistoryAndPinnedState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import Logging
import SQLiteData
import Observation

private let logger = Logger(label: "HistoryAndPinnedState")

@MainActor
@Observable
class HistoryAndPinnedStore {
    @ObservationIgnored @Dependency(\.defaultDatabase) var database

    public private(set) var lastError: Error?

    // MARK: - Filter-only Methods

    public func delete(filter: SearchFilter) {
        write("deleting filter") { db in
            try FilterHistoryEntry
                .delete()
                .where { $0.filter == SearchFilter.StableJSONRepresentation(queryOutput: filter) }
                .execute(db)

            try PinnedFilterEntry
                .delete()
                .where { $0.filter == SearchFilter.StableJSONRepresentation(queryOutput: filter) }
                .execute(db)
        }
    }

    public func pin(filter: SearchFilter) {
        write("pinning filter") { db in
            try PinnedFilterEntry
                .insert { PinnedFilterEntry(filter: filter) }
                .execute(db)
        }
    }

    public func unpin(filter: SearchFilter) {
        write("unpinning filter") { db in
            // Keep it around near the top since you just modified it.
            try FilterHistoryEntry
                .insert { FilterHistoryEntry(filter: filter) }
                .execute(db)

            try PinnedFilterEntry
                .delete()
                .where { $0.filter == SearchFilter.StableJSONRepresentation(queryOutput: filter) }
                .execute(db)
        }
    }

    // MARK: - Search Methods

    public func record(search: [SearchFilter]) {
        write("recording search") { db in
            try SearchHistoryEntry
                .insert { SearchHistoryEntry(filters: search) }
                .execute(db)

            try FilterHistoryEntry.insert {
                for filter in search {
                    FilterHistoryEntry(filter: filter)
                }
            }
            .execute(db)
        }
    }

    public func delete(search: [SearchFilter]) {
        write("deleting search") { db in
            try SearchHistoryEntry
                .delete()
                .where { $0.filters == [SearchFilter].StableJSONRepresentation(queryOutput: search) }
                .execute(db)
        }
    }

    // MARK: - Private Methods

    private func write(_ operation: String, _ block: (Database) throws -> Void) {
        do {
            try database.write(block)
        } catch {
            logger.error("error while \(operation)", metadata: [
                "error": "\(error)",
            ])
            lastError = error
        }
    }
}
