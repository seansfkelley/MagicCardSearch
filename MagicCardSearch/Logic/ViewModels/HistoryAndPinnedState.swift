//
//  HistoryAndPinnedState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import Logging
import SQLiteData

private let logger = Logger(label: "HistoryAndPinnedState")

// TODO: Remove this decorator once I have disentagled a bunch of the state management.
@MainActor
class HistoryAndPinnedState {
    @Dependency(\.defaultDatabase) var database

    private let pinnedFilter: PinnedFilterStore

    private(set) var lastError: Error?

    init(pinnedFilter: PinnedFilterStore) {
        self.pinnedFilter = pinnedFilter
    }

    // MARK: - Filter-only Methods

    public func delete(filter: SearchFilter) {
        perform("deleting filter") {
            try database.write { db in
                try FilterHistoryEntry.delete().where { $0.filter == SearchFilter.StableJSONRepresentation(queryOutput: filter) }.execute(db)
            }
            try pinnedFilter.unpin(filter)
        }
    }

    public func pin(filter: SearchFilter) {
        perform("pinning filter") {
            try pinnedFilter.pin(filter)
        }
    }

    public func unpin(filter: SearchFilter) {
        perform("unpinning filter") {
            // Keep it around near the top since you just modified it.
            try database.write { db in
                try FilterHistoryEntry.insert { FilterHistoryEntry(filter: filter) }.execute(db)
            }
            try pinnedFilter.unpin(filter)
        }
    }

    // MARK: - Search Methods

    public func delete(search: [SearchFilter]) {
        perform("deleting search") {
            try database.write { db in
                try SearchHistoryEntry.delete().where { $0.filters == [SearchFilter].StableJSONRepresentation(queryOutput: search) }.execute(db)
            }
        }
    }

    // MARK: - Private Methods

    private func perform(_ operation: String, _ block: () throws -> Void) {
        do {
            try block()
        } catch {
            logger.error("error while \(operation)", metadata: [
                "error": "\(error)",
            ])
            lastError = error
        }
    }

    private func perform<T>(_ operation: String, defaultValue: T, _ block: () throws -> T) -> T {
        do {
            return try block()
        } catch {
            logger.error("error while \(operation)", metadata: [
                "error": "\(error)",
            ])
            lastError = error
            return defaultValue
        }
    }
}
