import Foundation
import Logging
import SQLiteData
import Observation

private let logger = Logger(label: "HistoryAndPinnedState")

@MainActor
@Observable
class HistoryAndPinnedStore {
    public private(set) var lastError: Error?

    @ObservationIgnored private var database: any DatabaseWriter
    init(database: any DatabaseWriter) {
        self.database = database
    }

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

    public func pin(filter: SearchFilter, at date: Date = .init()) {
        write("pinning filter") { db in
            try PinnedFilterEntry
                .insert { PinnedFilterEntry(filter: filter, at: date) }
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

    public func record(search: [SearchFilter], at date: Date = .init()) {
        write("recording search") { db in
            try SearchHistoryEntry
                .insert { SearchHistoryEntry(filters: search, at: date) }
                .execute(db)

            try FilterHistoryEntry.insert {
                for filter in search {
                    FilterHistoryEntry(filter: filter, at: date)
                }
            }
            .execute(db)
        }
    }

    public func delete(search: [SearchFilter]) {
        write("deleting search by content") { db in
            try SearchHistoryEntry
                .delete()
                .where { $0.filters == [SearchFilter].StableJSONRepresentation(queryOutput: search) }
                .execute(db)

            try PinnedSearchEntry
                .delete()
                .where { $0.filters == [SearchFilter].StableJSONRepresentation(queryOutput: search) }
                .execute(db)
        }
    }

    public func delete(searches: some Collection<[SearchFilter]>) {
        guard !searches.isEmpty else { return }

        let serializedSearches = searches.map { [SearchFilter].StableJSONRepresentation(queryOutput: $0) }

        write("bulk-deleting searches") { db in
            try SearchHistoryEntry
                .delete()
                .where { $0.filters.in(serializedSearches) }
                .execute(db)

            try PinnedSearchEntry
                .delete()
                .where { $0.filters.in(serializedSearches) }
                .execute(db)
        }
    }

    public func pin(search: [SearchFilter], at date: Date = .init()) {
        write("pinning search") { db in
            try PinnedSearchEntry
                .insert { PinnedSearchEntry(filters: search, at: date) }
                .execute(db)
        }
    }

    public func unpin(search: [SearchFilter]) {
        write("unpinning search") { db in
            // Keep it around near the top since you just modified it.
            try SearchHistoryEntry
                .insert { SearchHistoryEntry(filters: search) }
                .execute(db)

            try PinnedSearchEntry
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
