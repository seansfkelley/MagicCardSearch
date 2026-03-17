import ScryfallKit
import OSLog
import Cache
import Observation

private let logger = Logger(subsystem: "MagicCardSearch", category: "CachingScryfallService")

@MainActor
class CachingScryfallService {
    static let shared = CachingScryfallService()

    private let client = ScryfallClient(logger: logger)

    private let rulingsCache: any StorageAware<UUID, [Card.Ruling]> = bestEffortCache(
        memory: .init(expiry: .days(30), countLimit: 500),
        disk: .init(name: "rulings", expiry: .days(30)),
    )

    private let tagsCache: any StorageAware<String, TaggerCard> = bestEffortCache(
        memory: .init(expiry: .days(7), countLimit: 500),
        disk: .init(name: "tags", expiry: .days(7)),
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
}
