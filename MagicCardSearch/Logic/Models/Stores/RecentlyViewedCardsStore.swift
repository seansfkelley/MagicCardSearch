import Foundation
import ScryfallKit
import OSLog
import SQLiteData
import Observation

private let logger = Logger(subsystem: "MagicCardSearch", category: "RecentlyViewedCardStore")

struct RecentlyViewedCard: Codable, Equatable {
    struct CardFace: Codable, Equatable {
        let name: String
        let imageUris: Card.ImageUris?
    }

    let id: UUID
    let viewedAt: Date
    let frontFace: CardFace
    let backFace: CardFace?
}

private let blobKey = "recentlyViewedCards"

@MainActor
@Observable
class RecentlyViewedCardsStore {
    private static let limit = 50

    @ObservationIgnored private var database: any DatabaseWriter
    init(database: any DatabaseWriter) {
        self.database = database
    }

    @ObservationIgnored
    @TransformedBlob(blobKey)
    public var cards: [RecentlyViewedCard]?

    public func add(card: Card) {
        let entry = RecentlyViewedCard(
            id: card.id,
            viewedAt: Date(),
            frontFace: .init(name: card.frontFace.name, imageUris: card.frontFace.imageUris),
            backFace: card.backFace.map { .init(name: $0.name, imageUris: $0.imageUris) }
        )

        var updated = (cards ?? []).filter { $0.id != card.id }
        updated.insert(entry, at: 0)
        if updated.count > Self.limit {
            updated = Array(updated.prefix(Self.limit))
        }

        do {
            let data = try JSONEncoder().encode(updated)
            try database.write { db in
                try BlobEntry
                    .insert { BlobEntry(key: blobKey, value: data) }
                    .execute(db)
            }
        } catch {
            logger.error("error adding recently viewed card error=\(error)")
        }
    }
}
