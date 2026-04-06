import ScryfallKit
import OSLog
import Cache
import Observation

private let logger = Logger(subsystem: "MagicCardSearch", category: "CachingScryfallService")

@MainActor
protocol FetchCardService {
    func fetchCard(byScryfallId id: UUID) async throws -> Card
    func fetchCard(byOracleId id: UUID) async throws -> Card?
    func fetchCard(byIllustrationId id: UUID) async throws -> Card?
    func fetchCard(byPrintingId id: UUID) async throws -> Card?
}

@MainActor
protocol TagsService {
    func tags(forCollectorNumber collectorNumber: String, inSet setCode: String) async throws -> TaggerCard?
}

@MainActor
protocol RulingsService {
    func rulings(forScryfallId id: UUID) async throws -> [Card.Ruling]
}

extension CachingScryfallService: FetchCardService {}
extension CachingScryfallService: TagsService {}
extension CachingScryfallService: RulingsService {}

@MainActor
class CachingScryfallService {
    static let shared = CachingScryfallService()

    private let client = ScryfallClient(logger: logger)

    private let rulingsCache: any StorageAware<UUID, [Card.Ruling]> = bestEffortCache(
        memory: .init(expiry: .days(30), countLimit: 500),
        disk: .init(name: "rulings", expiry: .days(30)),
    )

    private let tagsCache: any StorageAware<String, TaggerCard> = bestEffortCache(
        memory: .init(expiry: .days(30), countLimit: 500),
        disk: .init(name: "tags", expiry: .days(7)),
    )

    private let cardCache: any StorageAware<String, Card> = bestEffortCache(
        memory: .init(expiry: .days(30), countLimit: 500),
        disk: .init(name: "cards", expiry: .days(7)),
    )

    func rulings(forScryfallId id: UUID) async throws -> [Card.Ruling] {
        if let cached = try? rulingsCache.entry(forKey: id) {
            logger.debug("hit rulings cache for scryfall ID=\(id)")
            return cached.object
        }

        let rulings = try await client.getRulings(.scryfallID(id: id.uuidString))
        if rulings.hasMore ?? false {
            logger.warning("card with scryfall ID=\(id) has more than one page of rulings; ignoring")
        }

        do {
            try rulingsCache.setObject(rulings.data, forKey: id, expiry: nil)
            logger.debug("stored rulings cache value for scryfall ID=\(id)")
        } catch {
            logger.error("error while setting cache for rulings for card with scryfall ID=\(id) error=\(error)")
        }

        return rulings.data
    }

    func tags(forCollectorNumber collectorNumber: String, inSet setCode: String) async throws -> TaggerCard? {
        let cacheKey = "\(setCode)/\(collectorNumber)"

        if let cached = try? tagsCache.entry(forKey: cacheKey) {
            logger.debug("hit tags cache for set=\(setCode) collectorNumber=\(collectorNumber)")
            return cached.object
        }

        guard let card = try await TaggerCard.fetch(setCode: setCode, collectorNumber: collectorNumber) else {
            return nil
        }

        do {
            try tagsCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored tags cache value for set=\(setCode) collectorNumber=\(collectorNumber)")
        } catch {
            logger.error("error while setting cache for tags for set=\(setCode) collectorNumber=\(collectorNumber) error=\(error)")
        }

        return card
    }

    func fetchCard(byScryfallId id: UUID) async throws -> Card {
        let cacheKey = "scryfall/\(id.uuidString)"
        if let cached = try? cardCache.entry(forKey: cacheKey) {
            logger.debug("hit card cache for scryfall ID=\(id)")
            return cached.object
        }

        let card = try await client.getCard(identifier: .scryfallID(id: id.uuidString))

        do {
            try cardCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored card cache value for scryfall ID=\(id)")
        } catch {
            logger.error("error while setting cache for card with scryfall ID=\(id) error=\(error)")
        }

        return card
    }

    func fetchCard(byOracleId id: UUID) async throws -> Card? {
        let cacheKey = "oracle/\(id.uuidString)"
        if let cached = try? cardCache.entry(forKey: cacheKey) {
            logger.debug("hit card cache for oracle ID=\(id)")
            return cached.object
        }

        let results = try await client.searchCards(query: "oracleId:\(id.uuidString)")
        guard let card = results.data.first else { return nil }

        do {
            try cardCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored card cache value for oracle ID=\(id)")
        } catch {
            logger.error("error while setting cache for card with oracle ID=\(id) error=\(error)")
        }

        return card
    }

    func fetchCard(byIllustrationId id: UUID) async throws -> Card? {
        let cacheKey = "illustration/\(id.uuidString)"
        if let cached = try? cardCache.entry(forKey: cacheKey) {
            logger.debug("hit card cache for illustration ID=\(id)")
            return cached.object
        }

        let results = try await client.searchCards(query: "illustrationId:\(id.uuidString)")
        guard let card = results.data.first else { return nil }

        do {
            try cardCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored card cache value for illustration ID=\(id)")
        } catch {
            logger.error("error while setting cache for card with illustration ID=\(id) error=\(error)")
        }

        return card
    }

    func fetchCard(byPrintingId id: UUID) async throws -> Card? {
        let cacheKey = "printing/\(id.uuidString)"
        if let cached = try? cardCache.entry(forKey: cacheKey) {
            logger.debug("hit card cache for printing ID=\(id)")
            return cached.object
        }

        let results = try await client.searchCards(query: "printingId:\(id.uuidString)")
        guard let card = results.data.first else { return nil }

        do {
            try cardCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored card cache value for printing ID=\(id)")
        } catch {
            logger.error("error while setting cache for card with printing ID=\(id) error=\(error)")
        }

        return card
    }
}
