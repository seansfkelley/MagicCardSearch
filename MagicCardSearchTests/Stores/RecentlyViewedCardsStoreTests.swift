import Testing
import Foundation
import SQLiteData
import DependenciesTestSupport
@testable import MagicCardSearch

@Suite(.dependency(\.defaultDatabase, try appDatabase()))
@MainActor
class RecentlyViewedCardsStoreTests {
    @Dependency(\.defaultDatabase) var database
    var store: RecentlyViewedCardsStore!

    init() throws {
        store = RecentlyViewedCardsStore(database: database)
    }

    // MARK: - Utility

    private var allCards: [RecentlyViewedCard] {
        get throws {
            try database.read { db in
                try RecentlyViewedCard.order { $0.viewedAt.desc() }.fetchAll(db)
            }
        }
    }

    private func makeCard(name: String = "Lightning Bolt", id: UUID = UUID()) -> RecentlyViewedCard {
        return RecentlyViewedCard(id: id, frontCardFace: .init(name: name, imageUris: nil))
    }

    // MARK: - Tests

    @Test("adding a card inserts it into the store")
    func addCard() throws {
        let card = makeCard()
        store.add(card)

        let cards = try allCards
        try #require(cards.count == 1)
        #expect(cards[0].id == card.id)
    }

    @Test("adding the same card twice replaces the existing entry")
    func addDuplicateCard() throws {
        let id = UUID()
        let date1 = Date(timeIntervalSinceReferenceDate: 1000)
        let date2 = Date(timeIntervalSinceReferenceDate: 2000)

        store.add(makeCard(id: id).with(viewedAt: date1))
        store.add(makeCard(id: id).with(viewedAt: date2))

        let cards = try allCards
        try #require(cards.count == 1)
        #expect(cards[0].viewedAt == date2)
    }

    @Test("cards are returned most-recently-viewed first")
    func ordersByViewedAtDescending() throws {
        let id1 = UUID()
        let id2 = UUID()
        let id3 = UUID()

        store.add(makeCard(name: "First", id: id1).with(viewedAt: Date(timeIntervalSinceReferenceDate: 1000)))
        store.add(makeCard(name: "Second", id: id2).with(viewedAt: Date(timeIntervalSinceReferenceDate: 3000)))
        store.add(makeCard(name: "Third", id: id3).with(viewedAt: Date(timeIntervalSinceReferenceDate: 2000)))

        let cards = try allCards
        #expect(cards.map(\.id) == [id2, id3, id1])
    }

    @Test("garbage collection trims the store to the limit")
    func garbageCollectionTrimsToLimit() throws {
        for i in 0..<110 {
            var card = makeCard(id: UUID())
            card.viewedAt = Date(timeIntervalSinceReferenceDate: Double(i))
            store.add(card)
        }

        let cards = try allCards
        // 110 total, minus 1 that triggers GC, minus the limit which (abstraction break!) we know
        // would be left behind because we know 110 inserts only triggers one GC. This test should
        // be improved but whatever.
        #expect(cards.count == 110 - 1 - RecentlyViewedCardsStore.limit)
        #expect(cards.first?.viewedAt == Date(timeIntervalSinceReferenceDate: 109))
    }

    @Test("cards below hardLimit are not garbage collected")
    func noGarbageCollectionBelowHardLimit() throws {
        for i in 0..<RecentlyViewedCardsStore.limit {
            var card = makeCard(id: UUID())
            card.viewedAt = Date(timeIntervalSinceReferenceDate: Double(i))
            store.add(card)
        }

        let cards = try allCards
        #expect(cards.count == RecentlyViewedCardsStore.limit)
    }
}

// MARK: - Test Helpers

private extension RecentlyViewedCard {
    func with(viewedAt date: Date) -> RecentlyViewedCard {
        var copy = self
        copy.viewedAt = date
        return copy
    }
}
