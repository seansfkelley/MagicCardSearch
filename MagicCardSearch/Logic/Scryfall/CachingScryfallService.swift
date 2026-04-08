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

@MainActor
protocol RandomCardService {
    func randomCard(query: String?) async throws -> Card
}

@MainActor
protocol CardSearchService {
    func searchCards(
        query: String,
        unique: UniqueMode,
        order: SortMode?,
        sortDirection: SortDirection,
        page: Int,
    ) async throws -> ObjectList<Card>
}

extension CardSearchService {
    func searchCards(
        filters: [String],
        unique: UniqueMode,
        order: SortMode?,
        sortDirection: SortDirection,
        page: Int,
    ) async throws -> ObjectList<Card> {
        try await searchCards(
            query: filters.joined(separator: " "),
            unique: unique,
            order: order,
            sortDirection: sortDirection,
            page: page,
        )
    }

    func searchCards(
        filters: [FilterQuery<FilterTerm>],
        unique: UniqueMode,
        order: SortMode?,
        sortDirection: SortDirection,
        page: Int,
    ) async throws -> ObjectList<Card> {
        try await searchCards(
            query: filters.map { $0.description }.joined(separator: " "),
            unique: unique,
            order: order,
            sortDirection: sortDirection,
            page: page,
        )
    }
}

extension CachingScryfallService: FetchCardService {}
extension CachingScryfallService: TagsService {}
extension CachingScryfallService: RulingsService {}
extension CachingScryfallService: CardSearchService {}
extension CachingScryfallService: RandomCardService {}

private struct SearchCacheKey: Hashable {
    // n.b. we cannot make this [String] and then sort it to canonicalize the cache key -- ordering
    // matters for multiply-specified singleton filters like `prefer`.
    let query: String
    let unique: UniqueMode
    let order: SortMode?
    let sortDirection: SortDirection
    let page: Int
}

@MainActor
class CachingScryfallService {
    static let shared = CachingScryfallService()

    private let client = ScryfallClient(logger: logger)

    // Sliding window rate limiters per Scryfall's two-tier limits.
    private let searchLimiter = RateLimiter(maxRequests: 2)   // /cards/search, /cards/random
    private let fetchLimiter  = RateLimiter(maxRequests: 10)  // /cards/{id}, /cards/{id}/rulings

    private let rulingsCache: any StorageAware<UUID, [Card.Ruling]> = bestEffortCache(
        // 30 days: rulings basically never change.
        memory: .init(expiry: .days(30), countLimit: 500),
        disk: .init(name: "rulings", expiry: .days(30)),
    )

    private let tagsCache: any StorageAware<String, TaggerCard> = bestEffortCache(
        // 7 days: tags rarely change, but are user-editable, so this is an acceptable delay.
        memory: .init(expiry: .days(7), countLimit: 500),
        disk: .init(name: "tags", expiry: .days(7)),
    )

    private let cardCache: any StorageAware<String, Card> = bestEffortCache(
        // 30 days: cards basically never change.
        memory: .init(expiry: .days(30), countLimit: 500),
        disk: .init(name: "cards", expiry: .days(7)),
    )

    private let cardSearchCache: any StorageAware<SearchCacheKey, ObjectList<Card>> = bestEffortCache(
        // 1 day: spoilers may change which cards turn up in any given search, but spoilers only
        // cycle around once per day during spoiler seasons.
        memory: .init(expiry: .days(1), countLimit: 100),
        disk: .init(name: "cardSearch", expiry: .days(1)),
    )

    func rulings(forScryfallId id: UUID) async throws -> [Card.Ruling] {
        if let cached = try? rulingsCache.entry(forKey: id) {
            logger.debug("hit rulings cache for scryfall ID=\(id)")
            return cached.object
        }

        try await fetchLimiter.waitForSlot()
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

        try await fetchLimiter.waitForSlot()
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

        try await fetchLimiter.waitForSlot()
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

        try await searchLimiter.waitForSlot()
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

        try await searchLimiter.waitForSlot()
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

        try await searchLimiter.waitForSlot()
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

    func randomCard(query: String?) async throws -> Card {
        try await searchLimiter.waitForSlot()
        return try await client.getRandomCard(query: query)
    }

    func searchCards(query: String, unique: UniqueMode, order: SortMode?, sortDirection: SortDirection, page: Int) async throws -> ObjectList<Card> {
        let cacheKey = SearchCacheKey(
            query: query,
            unique: unique,
            order: order,
            sortDirection: sortDirection,
            page: page,
        )

        if let cached = try? cardSearchCache.entry(forKey: cacheKey) {
            logger.debug("hit card search cache for query=\(query) page=\(page)")
            return cached.object
        }

        try await searchLimiter.waitForSlot()
        let results = try await client.searchCards(
            query: query,
            unique: unique,
            order: order,
            sortDirection: sortDirection,
            page: page,
        )

        do {
            try cardSearchCache.setObject(results, forKey: cacheKey, expiry: nil)
            logger.debug("stored card search cache value for query=\(query) page=\(page)")
        } catch {
            logger.error("error while setting cache for search query=\(query) page=\(page) error=\(error)")
        }

        return results
    }
}
