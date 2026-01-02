//
//  BookmarkedCardsState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-01.
//
import Foundation
import Logging
import SQLiteData
import ScryfallKit

private let logger = Logger(label: "HistoryAndPinnedState")

@MainActor
class BookmarkedCardsState {
    @Dependency(\.defaultDatabase) var database

    public private(set) var lastError: Error?

    public func bookmark(card: Card) {
        write("bookmarking card") { db in
            try BookmarkedCard
                .insert { BookmarkedCard.from(card: card) }
                .execute(db)
        }
    }

    public func unbookmark(id: UUID) {
        write("unbookmarking card") { db in
            try BookmarkedCard
                .delete()
                .where { $0.id == id }
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
