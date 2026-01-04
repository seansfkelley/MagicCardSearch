import SQLiteData
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

@Table
struct BookmarkedCard: Identifiable {
    var id: UUID
    var name: String
    var typeLine: String?
    @Column(as: BookmarkableCardFace.JSONRepresentation.self)
    var frontCardFace: BookmarkableCardFace
    @Column(as: BookmarkableCardFace?.JSONRepresentation.self)
    var backCardFace: BookmarkableCardFace?
    var setCode: String
    var setName: String
    var collectorNumber: String
    var releasedAt: Date
    var bookmarkedAt: Date

    public static func from(card: Card) -> BookmarkedCard {
        self.init(
            id: card.id,
            name: card.name,
            typeLine: card.typeLine,
            frontCardFace: BookmarkableCardFace.front(for: card),
            backCardFace: BookmarkableCardFace.back(for: card),
            setCode: card.set.uppercased(),
            setName: card.setName,
            collectorNumber: card.collectorNumber,
            releasedAt: card.releasedAtAsDate ?? Date(),
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
