import Foundation
import ScryfallKit
import OSLog
import SQLiteData
import Observation

private let logger = Logger(subsystem: "MagicCardSearch", category: "RecentlyViewedCardStore")

@Table
struct RecentlyViewedCard: Identifiable {
    struct CardFace: Codable, Equatable {
        let name: String
        let imageUris: Card.ImageUris?
    }

    var id: UUID
    var viewedAt: Date
    @Column(as: CardFace.JSONRepresentation.self)
    var frontCardFace: CardFace
    @Column(as: CardFace?.JSONRepresentation.self)
    var backCardFace: CardFace?

    init(card: Card, viewedAt: Date = Date()) {
        id = card.id
        self.viewedAt = viewedAt
        frontCardFace = .init(name: card.frontFace.name, imageUris: card.frontFace.imageUris)
        backCardFace = card.backFace.map { .init(name: $0.name, imageUris: $0.imageUris) }
    }
}

extension RecentlyViewedCard: CardDisplayable {
    var frontFace: CardFaceDisplayable { frontCardFace }
    var backFace: CardFaceDisplayable? { backCardFace }
}

extension RecentlyViewedCard.CardFace: CardFaceDisplayable {}

@MainActor
@Observable
class RecentlyViewedCardsStore {
    public static let limit = 50
    private static let hardLimit = 100

    @ObservationIgnored private var database: any DatabaseWriter

    init(database: any DatabaseWriter) {
        self.database = database
    }

    public func add(card: Card) {
        do {
            try database.write { db in
                try RecentlyViewedCard
                    .insert { RecentlyViewedCard(card: card) }
                    .execute(db)

                let total = try RecentlyViewedCard.count().fetchOne(db) ?? 0
                // Is this being too clever?
                if total > Self.hardLimit {
                    let cutoff = try RecentlyViewedCard
                        .order { $0.viewedAt.desc() }
                        .limit(1, offset: Self.limit)
                        .select { $0.viewedAt }
                        .fetchAll(db)
                        .last

                    if let cutoff {
                        try RecentlyViewedCard
                            .delete()
                            .where { $0.viewedAt.lt(cutoff) }
                            .execute(db)
                    }
                }
            }
        } catch {
            logger.error("error adding recently viewed card error=\(error)")
        }
    }
}
