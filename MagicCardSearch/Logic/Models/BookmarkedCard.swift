//
//  BookmarkedCard.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2026-01-01.
//
import SwiftData
import Foundation
import ScryfallKit

struct BookmarkableCardFace: Codable {
    let name: String
    let imageUris: Card.ImageUris?

    static func front(for card: Card) -> BookmarkableCardFace {
        .init(name: card.frontFace.name, imageUris: card.frontFace.imageUris)
    }

    static func back(for card: Card) -> BookmarkableCardFace? {
        card.backFace.map { .init(name: $0.name, imageUris: $0.imageUris) }
    }
}

@Model
final class BookmarkedCard {
    @Attribute(.unique)
    var id: UUID
    var name: String
    var typeLine: String?
    var frontCardFace: BookmarkableCardFace
    var backCardFace: BookmarkableCardFace?
    var setCode: String
    var setName: String
    var collectorNumber: String
    var releasedAt: Date?
    var bookmarkedAt: Date

    private init(
        id: UUID,
        name: String,
        typeLine: String? = nil,
        frontFace: BookmarkableCardFace,
        backFace: BookmarkableCardFace? = nil,
        setCode: String,
        setName: String,
        collectorNumber: String,
        releasedAt: Date? = nil,
        bookmarkedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.typeLine = typeLine
        self.frontCardFace = frontFace
        self.backCardFace = backFace
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
            frontFace: BookmarkableCardFace.front(for: card),
            backFace: BookmarkableCardFace.back(for: card),
            setCode: card.set.uppercased(),
            setName: card.setName,
            collectorNumber: card.collectorNumber,
            releasedAt: card.releasedAtAsDate,
            bookmarkedAt: Date()
        )
    }
}

// MARK: - CardDisplayable Conformance
extension BookmarkedCard: CardDisplayable {
    var frontFace: CardFaceDisplayable {
        frontCardFace
    }
    
    var backFace: CardFaceDisplayable? {
        backCardFace
    }
}
