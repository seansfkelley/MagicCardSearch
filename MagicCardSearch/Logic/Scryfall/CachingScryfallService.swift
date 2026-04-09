import ScryfallKit
import OSLog
import Cache
import Observation

private let logger = Logger(subsystem: "MagicCardSearch", category: "CachingScryfallService")
private let signposter = OSSignposter(logger: logger)

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
protocol NamedCardService {
    func fetchCard(byExactName name: String, set: String?) async throws -> Card
    func fetchCard(byFuzzyName name: String, set: String?) async throws -> Card
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
extension CachingScryfallService: NamedCardService {}

private enum CardCacheKey: Hashable {
    case scryfallId(UUID)
    case oracleId(UUID)
    case illustrationId(UUID)
    case printingId(UUID)
    case exactName(String, set: String?)
    case fuzzyName(String, set: String?)
}

private struct SearchCacheKey: Hashable {
    // n.b. we cannot make this [String] and then sort it to canonicalize the cache key -- ordering
    // matters for multiply-specified singleton filters like `prefer`.
    let query: String
    let unique: UniqueMode
    let order: SortMode?
    let sortDirection: SortDirection
    let page: Int
}

private struct TagsCacheKey: Hashable {
    let collectorNumber: String
    let setCode: String
}

@MainActor
class CachingScryfallService {
    private static let cacheBustingVersion = 1
    private static let cacheBustingVersionKey = "CachingScryfallService.cacheBustingVersion"

    static let shared = CachingScryfallService()

    private let client = ScryfallClient(logger: logger)

    // Sliding window rate limiters per Scryfall's two-tier limits.
    private let searchLimiter = RateLimiter("2/s", requests: 2, per: .seconds(1))   // /cards/search, /cards/random
    private let fetchLimiter = RateLimiter("10/s", requests: 10, per: .seconds(1))  // /cards/{id}, /cards/{id}/rulings

    private let rulingsCache: any StorageAware<UUID, [Card.Ruling]> = bestEffortCache(
        // 30 days: rulings basically never change.
        memory: .init(expiry: .days(30), countLimit: 500),
        disk: .init(name: "rulings", expiry: .days(30)),
    )

    private let tagsCache: any StorageAware<TagsCacheKey, TaggerCard> = bestEffortCache(
        // 7 days: tags rarely change, but are user-editable, so this is an acceptable delay.
        memory: .init(expiry: .days(7), countLimit: 500),
        disk: .init(name: "tags", expiry: .days(7)),
    )

    private let cardCache: any StorageAware<CardCacheKey, Card> = bestEffortCache(
        // 30 days: cards basically never change.
        memory: .init(expiry: .days(30), countLimit: 500),
        disk: .init(name: "cards", expiry: .days(30)),
    )

    private let cardSearchCache: any StorageAware<SearchCacheKey, ObjectList<Card>> = bestEffortCache(
        // 1 hour: spoilers may change which cards turn up in any given search, but spoilers cycle
        // multiple times per day during the height of spoiler season. How far behind is okay?
        memory: .init(expiry: .hours(1), countLimit: 200),
        disk: .init(name: "cardSearch", expiry: .hours(1)),
    )

    init() {
        let stored = UserDefaults.standard.integer(forKey: Self.cacheBustingVersionKey)
        if stored != Self.cacheBustingVersion {
            logger.info("\(Self.cacheBustingVersionKey) changed (\(stored) → \(Self.cacheBustingVersion)); dumping all caches")
            dumpCaches()
            UserDefaults.standard.set(Self.cacheBustingVersion, forKey: Self.cacheBustingVersionKey)
        } else {
            logger.info("\(Self.cacheBustingVersionKey) changed; will not dump caches")
        }
    }

    @discardableResult
    func dumpCaches() -> Bool {
        func dump(_ cache: any StorageAware, _ named: String) -> Bool {
            do {
                try cache.removeAll()
                logger.info("successfully dumped all caches")
                return true
            } catch {
                logger.error("failed to dump cache named=\(named) with error=\(error)")
                return false
            }
        }

        var success = true
        // n.b. ordering matters to avoid short-circuiting
        success = dump(rulingsCache, "rulings") && success
        success = dump(tagsCache, "tags") && success
        success = dump(cardCache, "card") && success
        success = dump(cardSearchCache, "searches") && success
        return success
    }

    func rulings(forScryfallId id: UUID) async throws -> [Card.Ruling] {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("rulings", id: signpostID, "scryfallId: \(id.uuidString)")
        defer { signposter.endInterval("rulings", state) }

        if let cached = try? rulingsCache.object(forKey: id) {
            logger.debug("hit rulings cache for scryfall ID=\(id)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("rulings", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("rulings", waitState) }
            try await fetchLimiter.waitForSlot()
        }

        let rulings: ObjectList<Card.Ruling>
        do {
            let networkState = signposter.beginInterval("rulings", id: signpostID, "network")
            defer { signposter.endInterval("rulings", networkState) }
            rulings = try await client.getRulings(.scryfallID(id: id.uuidString))
        }

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
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("tags", id: signpostID, "\(setCode)/\(collectorNumber)")
        defer { signposter.endInterval("tags", state) }

        let cacheKey = TagsCacheKey(collectorNumber: collectorNumber, setCode: setCode)

        if let cached = try? tagsCache.object(forKey: cacheKey) {
            logger.debug("hit tags cache for set=\(setCode) collectorNumber=\(collectorNumber)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("tags", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("tags", waitState) }
            try await fetchLimiter.waitForSlot()
        }

        let fetched: TaggerCard?
        do {
            let networkState = signposter.beginInterval("tags", id: signpostID, "network")
            defer { signposter.endInterval("tags", networkState) }
            fetched = try await TaggerCard.fetch(setCode: setCode, collectorNumber: collectorNumber)
        }
        guard let card = fetched else { return nil }

        do {
            try tagsCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored tags cache value for set=\(setCode) collectorNumber=\(collectorNumber)")
        } catch {
            logger.error("error while setting cache for tags for set=\(setCode) collectorNumber=\(collectorNumber) error=\(error)")
        }

        return card
    }

    func fetchCard(byScryfallId id: UUID) async throws -> Card {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("fetchCard", id: signpostID, "scryfallId: \(id.uuidString)")
        defer { signposter.endInterval("fetchCard", state) }

        let cacheKey = CardCacheKey.scryfallId(id)

        if let cached = try? cardCache.object(forKey: cacheKey) {
            logger.debug("hit card cache for scryfall ID=\(id)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("fetchCard", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("fetchCard", waitState) }
            try await fetchLimiter.waitForSlot()
        }

        let card: Card
        do {
            let networkState = signposter.beginInterval("fetchCard", id: signpostID, "network")
            defer { signposter.endInterval("fetchCard", networkState) }
            card = try await client.getCard(identifier: .scryfallID(id: id.uuidString))
        }

        do {
            try cardCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored card cache value for scryfall ID=\(id)")
        } catch {
            logger.error("error while setting cache for card with scryfall ID=\(id) error=\(error)")
        }

        return card
    }

    func fetchCard(byOracleId id: UUID) async throws -> Card? {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("fetchCard", id: signpostID, "oracleId: \(id.uuidString)")
        defer { signposter.endInterval("fetchCard", state) }

        let cacheKey = CardCacheKey.oracleId(id)

        if let cached = try? cardCache.object(forKey: cacheKey) {
            logger.debug("hit card cache for oracle ID=\(id)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("fetchCard", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("fetchCard", waitState) }
            try await searchLimiter.waitForSlot()
        }

        let results: ObjectList<Card>
        do {
            let networkState = signposter.beginInterval("fetchCard", id: signpostID, "network")
            defer { signposter.endInterval("fetchCard", networkState) }
            results = try await client.searchCards(query: "oracleId:\(id.uuidString)")
        }
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
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("fetchCard", id: signpostID, "illustrationId: \(id.uuidString)")
        defer { signposter.endInterval("fetchCard", state) }

        let cacheKey = CardCacheKey.illustrationId(id)

        if let cached = try? cardCache.object(forKey: cacheKey) {
            logger.debug("hit card cache for illustration ID=\(id)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("fetchCard", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("fetchCard", waitState) }
            try await searchLimiter.waitForSlot()
        }

        let results: ObjectList<Card>
        do {
            let networkState = signposter.beginInterval("fetchCard", id: signpostID, "network")
            defer { signposter.endInterval("fetchCard", networkState) }
            results = try await client.searchCards(query: "illustrationId:\(id.uuidString)")
        }
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
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("fetchCard", id: signpostID, "printingId: \(id.uuidString)")
        defer { signposter.endInterval("fetchCard", state) }

        let cacheKey = CardCacheKey.printingId(id)

        if let cached = try? cardCache.object(forKey: cacheKey) {
            logger.debug("hit card cache for printing ID=\(id)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("fetchCard", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("fetchCard", waitState) }
            try await searchLimiter.waitForSlot()
        }

        let results: ObjectList<Card>
        do {
            let networkState = signposter.beginInterval("fetchCard", id: signpostID, "network")
            defer { signposter.endInterval("fetchCard", networkState) }
            results = try await client.searchCards(query: "printingId:\(id.uuidString)")
        }
        guard let card = results.data.first else { return nil }

        do {
            try cardCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored card cache value for printing ID=\(id)")
        } catch {
            logger.error("error while setting cache for card with printing ID=\(id) error=\(error)")
        }

        return card
    }

    func fetchCard(byExactName name: String, set: String?) async throws -> Card {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("fetchCard", id: signpostID, "exactName: \(name)")
        defer { signposter.endInterval("fetchCard", state) }

        let cacheKey = CardCacheKey.exactName(name, set: set)

        if let cached = try? cardCache.object(forKey: cacheKey) {
            logger.debug("hit card cache for exact name=\(name)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("fetchCard", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("fetchCard", waitState) }
            try await searchLimiter.waitForSlot()
        }

        let card: Card
        do {
            let networkState = signposter.beginInterval("fetchCard", id: signpostID, "network")
            defer { signposter.endInterval("fetchCard", networkState) }
            card = try await client.getCardByName(exact: name, set: set)
        }

        do {
            try cardCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored card cache value for exact name=\(name)")
        } catch {
            logger.error("error while setting cache for card with exact name=\(name) error=\(error)")
        }

        return card
    }

    func fetchCard(byFuzzyName name: String, set: String?) async throws -> Card {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("fetchCard", id: signpostID, "fuzzyName: \(name)")
        defer { signposter.endInterval("fetchCard", state) }

        let cacheKey = CardCacheKey.fuzzyName(name, set: set)

        if let cached = try? cardCache.object(forKey: cacheKey) {
            logger.debug("hit card cache for fuzzy name=\(name)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("fetchCard", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("fetchCard", waitState) }
            try await searchLimiter.waitForSlot()
        }

        let card: Card
        do {
            let networkState = signposter.beginInterval("fetchCard", id: signpostID, "network")
            defer { signposter.endInterval("fetchCard", networkState) }
            card = try await client.getCardByName(fuzzy: name, set: set)
        }

        do {
            try cardCache.setObject(card, forKey: cacheKey, expiry: nil)
            logger.debug("stored card cache value for fuzzy name=\(name)")
        } catch {
            logger.error("error while setting cache for card with fuzzy name=\(name) error=\(error)")
        }

        return card
    }

    func randomCard(query: String?) async throws -> Card {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("randomCard", id: signpostID, "query: \(query ?? "none")")
        defer { signposter.endInterval("randomCard", state) }

        do {
            let waitState = signposter.beginInterval("randomCard", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("randomCard", waitState) }
            try await searchLimiter.waitForSlot()
        }

        let networkState = signposter.beginInterval("randomCard", id: signpostID, "network")
        defer { signposter.endInterval("randomCard", networkState) }
        return try await client.getRandomCard(query: query)
    }

    func searchCards(query: String, unique: UniqueMode, order: SortMode?, sortDirection: SortDirection, page: Int) async throws -> ObjectList<Card> {
        let signpostID = signposter.makeSignpostID()
        let state = signposter.beginInterval("searchCards", id: signpostID, "query: \(query) page: \(page)")
        defer { signposter.endInterval("searchCards", state) }

        let cacheKey = SearchCacheKey(
            query: query,
            unique: unique,
            order: order,
            sortDirection: sortDirection,
            page: page,
        )

        if let cached = try? cardSearchCache.object(forKey: cacheKey) {
            logger.debug("hit card search cache for query=\(query) unique=\(unique) order=\(order.map(\.description) ?? "<default>") dir=\(sortDirection) page=\(page)")
            return cached
        }

        do {
            let waitState = signposter.beginInterval("searchCards", id: signpostID, "waitForSlot")
            defer { signposter.endInterval("searchCards", waitState) }
            try await searchLimiter.waitForSlot()
        }

        let results: ObjectList<Card>
        do {
            let networkState = signposter.beginInterval("searchCards", id: signpostID, "network")
            defer { signposter.endInterval("searchCards", networkState) }
            results = try await client.searchCards(
                query: query,
                unique: unique,
                order: order,
                sortDirection: sortDirection,
                page: page,
            )
        }

        do {
            try cardSearchCache.setObject(results, forKey: cacheKey, expiry: nil)
            logger.debug("stored card search cache value for query=\(query) unique=\(unique) order=\(order.map(\.description) ?? "<default>") dir=\(sortDirection) page=\(page)")
        } catch {
            logger.error("error while setting cache for search query=\(query) unique=\(unique) order=\(order.map(\.description) ?? "<default>") dir=\(sortDirection) page=\(page) error=\(error)")
        }

        return results
    }
}

extension UniqueMode: @retroactive CustomStringConvertible {
    public var description: String { rawValue }
}

extension SortMode: @retroactive CustomStringConvertible {
    public var description: String { rawValue }
}

extension SortDirection: @retroactive CustomStringConvertible {
    public var description: String { rawValue }
}
