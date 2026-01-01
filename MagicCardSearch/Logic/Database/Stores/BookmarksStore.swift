//
//  BookmarkedCardStore.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import SQLite
import Foundation
import ScryfallKit

enum BookmarkSortMode: String, CaseIterable, Identifiable {
    case name
    case dateAddedNewest
    case dateAddedOldest
    case releaseDateNewest
    case releaseDateOldest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .name:
            return "Name"
        case .releaseDateNewest, .releaseDateOldest:
            return "Release Date"
        case .dateAddedNewest, .dateAddedOldest:
            return "Date Added"
        }
    }

    var subtitle: String? {
        switch self {
        case .name:
            return nil
        case .releaseDateNewest, .dateAddedNewest:
            return "Newest First"
        case .releaseDateOldest, .dateAddedOldest:
            return "Oldest First"
        }
    }
}

struct BookmarksStore {
    struct Row: Codable, Identifiable {
        let id: UUID
        let name: String
        let typeLine: String?
        let smallImageUrl: String?
        let setCode: String
        let setName: String
        let collectorNumber: String
        let releasedAt: Date?
        let bookmarkedAt: Date
    }

    private let db: Connection
    private let table = Table("bookmarks")

    private let id = Expression<UUID>("id")
    private let name = Expression<String>("name")
    private let typeLine = Expression<String?>("type_line")
    private let smallImageUrl = Expression<String?>("small_image_url")
    private let setCode = Expression<String>("set_code")
    private let setName = Expression<String>("set_name")
    private let collectorNumber = Expression<String>("collector_number")
    private let releasedAt = Expression<Date?>("released_at")
    private let bookmarkedAt = Expression<Date>("bookmarked_at")

    internal init(db: Connection) {
        self.db = db
    }

    func add(_ card: Card) throws {
        try db.run(
            table.insert(
                or: .ignore,
                id <- card.id,
                name <- card.name,
                typeLine <- card.typeLine,
                smallImageUrl <- card.imageUris?.small,
                setCode <- card.set.uppercased(),
                setName <- card.setName,
                collectorNumber <- card.collectorNumber,
                releasedAt <- card.releasedAtAsDate,
                bookmarkedAt <- Date(),
            )
        )
    }

    func remove(_ cardId: UUID) throws {
        try db.run(table.filter(id == cardId).delete())
    }

    func remove(ids: [UUID]) throws {
        guard !ids.isEmpty else { return }
        try db.run(table.filter(ids.contains(id)).delete())
    }

    func contains(_ cardId: UUID) throws -> Bool {
        try db.pluck(table.filter(id == cardId)) != nil
    }

    func allBookmarks(sortedBy sort: BookmarkSortMode) throws -> [Row] {
        let query: Table
        
        switch sort {
        case .name:
            query = table.order(name.asc, setCode.asc, collectorNumber.asc)
            
        case .releaseDateNewest:
            query = table.order(releasedAt.desc, name.asc, setCode.asc, collectorNumber.asc)
            
        case .releaseDateOldest:
            query = table.order(releasedAt.asc, name.asc, setCode.asc, collectorNumber.asc)
            
        case .dateAddedNewest:
            query = table.order(bookmarkedAt.desc, name.asc, setCode.asc, collectorNumber.asc)
            
        case .dateAddedOldest:
            query = table.order(bookmarkedAt.asc, name.asc, setCode.asc, collectorNumber.asc)
        }
        
        return try db.prepareRowIterator(query).map { try $0.decode() }
    }
}
