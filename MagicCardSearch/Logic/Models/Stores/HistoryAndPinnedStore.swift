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
        }
    }

    public func delete(search id: Int64?) {
        guard let id else { return }

        write("deleting search by ID") { db in
            try SearchHistoryEntry
                .delete()
                .where { $0.id == id }
                .execute(db)
        }
    }

    public func delete(searches ids: Set<Int64?>) {
        write("bulk-deleting searches by ID") { db in
            try SearchHistoryEntry
                .delete()
                .where { $0.id.in(Array(ids)) }
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
