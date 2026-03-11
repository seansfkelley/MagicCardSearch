import ScryfallKit
import OSLog
import Cache
import Observation

private let logger = Logger(subsystem: "MagicCardSearch", category: "CachingScryfallService")

@Observable
class CachingScryfallService {
    @ObservationIgnored
    private let client = ScryfallClient(logger: logger)

    @ObservationIgnored
    private let rulingsCache: any StorageAware<UUID, [Card.Ruling]> = bestEffortCache(
        memory: .init(expiry: .never, countLimit: 500),
        disk: .init(name: "rulings", expiry: .seconds(60 * 60 * 24 * 30)),
    )

    func rulings(forScryfallId id: UUID) async throws -> [Card.Ruling] {
        if let cached = try? rulingsCache.entry(forKey: id) {
            return cached.object
        }

        let rulings = try await client.getRulings(.scryfallID(id: id.uuidString))
        if rulings.hasMore ?? false {
            logger.warning("card with scryfall ID=\(id) has more than one page of rulings; ignoring")
        }

        do {
            try rulingsCache.setObject(rulings.data, forKey: id, expiry: nil)
        } catch {
            logger.error("error while setting cache for rulings for card with scryfall ID=\(id) error=\(error)")
        }

        return rulings.data
    }
}
