import Foundation
import OSLog
import SQLiteData
import ScryfallKit

private let logger = Logger(subsystem: "MagicCardSearch", category: "BookmarkedCardsStore")

@MainActor
@Observable
class BookmarkedCardsStore {
    public private(set) var lastError: Error?

    @ObservationIgnored private var database: any DatabaseWriter

    init(database: any DatabaseWriter) {
        self.database = database
    }

    public func bookmark(card: Card) {
        write("bookmarking card") { db in
            try BookmarkedCard
                .insert { BookmarkedCard.from(card: card) }
                .execute(db)
        }
    }

    public func bookmark(card: BookmarkedCard) {
        write("bookmarking card") { db in
            try BookmarkedCard
                .insert { card }
                .execute(db)
        }
    }

    public func unbookmark(id: UUID) {
        write("unbookmarking card") { db in
            try BookmarkedCard
                .delete()
                .where { $0.id.eq(id) }
                .execute(db)
        }
    }

    public func unbookmark(ids: any Collection<UUID>) {
        guard !ids.isEmpty else { return }

        write("unbookmarking multiple cards") { db in
            try BookmarkedCard
                .delete()
                .where { $0.id.in(Array(ids)) }
                .execute(db)
        }
    }

    // MARK: - Private Methods

    private func write(_ operation: String, _ block: (Database) throws -> Void) {
        do {
            logger.info("\(operation)")
            try database.write(block)
        } catch {
            logger.error("error while performing operation=\(operation) error=\(error)")
            lastError = error
        }
    }
}
