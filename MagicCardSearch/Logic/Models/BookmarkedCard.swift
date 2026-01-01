//
//  BookmarkedCard.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-01.
//
import SwiftData
import Foundation
import ScryfallKit

@Model
final class BookmarkedCard {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var typeLine: String?
    var smallImageUrl: String?
    var setCode: String
    var setName: String
    var collectorNumber: String
    var releasedAt: Date?
    var bookmarkedAt: Date

    init(
        id: UUID,
        name: String,
        typeLine: String? = nil,
        smallImageUrl: String? = nil,
        setCode: String,
        setName: String,
        collectorNumber: String,
        releasedAt: Date? = nil,
        bookmarkedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.typeLine = typeLine
        self.smallImageUrl = smallImageUrl
        self.setCode = setCode
        self.setName = setName
        self.collectorNumber = collectorNumber
        self.releasedAt = releasedAt
        self.bookmarkedAt = bookmarkedAt
    }

    convenience init(from card: Card) {
        self.init(
            id: card.id,
            name: card.name,
            typeLine: card.typeLine,
            smallImageUrl: card.primaryImageUris?.small,
            setCode: card.set.uppercased(),
            setName: card.setName,
            collectorNumber: card.collectorNumber,
            releasedAt: card.releasedAtAsDate,
            bookmarkedAt: Date()
        )
    }
}
