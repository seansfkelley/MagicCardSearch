import Foundation
import ScryfallKit
import OSLog
import SwiftSoup
import Cache

private let logger = Logger(subsystem: "MagicCardSearch", category: "ScryfallCatalogs")

private let jsonDecoder: JSONDecoder = {
    var decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    return decoder
}()
private let jsonEncoder: JSONEncoder = {
    var encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    return encoder
}()

private typealias CatalogType = Catalog.`Type`

// MARK: - CachedBlob

@propertyWrapper
class CachedBlob<Value: Codable> {
    private let key: String
    private var valueCache: Result<Value, Error>?
    var storage: Storage<String, Data>?

    init(_ key: String) {
        self.key = key
    }

    var wrappedValue: Value? {
        if case .success(let value) = valueCache { return value }

        guard let storage else { return nil }

        do {
            let data = try storage.object(forKey: key)
            let value = try jsonDecoder.decode(Value.self, from: data)
            valueCache = .success(value)
            return value
        } catch {
            logger.warning("failed to load or decode cached value for key=\(self.key) error=\(error)")
            valueCache = .failure(error)
            return nil
        }
    }

    var projectedValue: CachedBlob<Value> { self }

    func store(_ value: Value) {
        guard let storage else {
            logger.warning("attempted to store value for key=\(self.key) but storage is nil")
            return
        }
        do {
            let data = try jsonEncoder.encode(value)
            try storage.setObject(data, forKey: key)
            valueCache = .success(value)
        } catch {
            logger.error("failed to encode or cache value for key=\(self.key) error=\(error)")
        }
    }
}

// MARK: - CachedBlobProtocol

protocol CachedBlobProtocol: AnyObject {
    var storage: Storage<String, Data>? { get set }
}

extension CachedBlob: CachedBlobProtocol {}

// MARK: - ScryfallCatalogs

@MainActor
@Observable
class ScryfallCatalogs {
    public private(set) var catalogChangeNonce: Int = 0

    @ObservationIgnored
    @CachedBlob("sets")
    public var sets: [SetCode: MTGSet]?

    @ObservationIgnored
    @CachedBlob("symbology")
    public var symbology: [SymbolCode: Card.Symbol]?

    @ObservationIgnored
    @CachedBlob("symbolSvgs")
    public var symbolSvgs: [SymbolCode: Data]?

    @ObservationIgnored
    @CachedBlob("artTags")
    public var artTags: [String]?

    @ObservationIgnored
    @CachedBlob("oracleTags")
    public var oracleTags: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.abilityWords.rawValue)
    public var abilityWords: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.artifactTypes.rawValue)
    public var artifactTypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.artistNames.rawValue)
    public var artistNames: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.battleTypes.rawValue)
    public var battleTypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.cardNames.rawValue)
    public var cardNames: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.cardTypes.rawValue)
    public var cardTypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.creatureTypes.rawValue)
    public var creatureTypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.enchantmentTypes.rawValue)
    public var enchantmentTypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.flavorWords.rawValue)
    public var flavorWords: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.keywordAbilities.rawValue)
    public var keywordAbilities: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.keywordActions.rawValue)
    public var keywordActions: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.landTypes.rawValue)
    public var landTypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.loyalties.rawValue)
    public var loyalties: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.planeswalkerTypes.rawValue)
    public var planeswalkerTypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.powers.rawValue)
    public var powers: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.spellTypes.rawValue)
    public var spellTypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.supertypes.rawValue)
    public var supertypes: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.toughnesses.rawValue)
    public var toughnesses: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.watermarks.rawValue)
    public var watermarks: [String]?

    @ObservationIgnored
    @CachedBlob(CatalogType.wordBank.rawValue)
    public var wordBank: [String]?

    // This is pretty foul but it's the best I can figure out without resorting to a macro or
    // some weird indirect initialization thunk specified on every single field.
    private var allBlobs: [any CachedBlobProtocol] {
        [
            $sets, $symbology, $symbolSvgs, $artTags, $oracleTags,
            $abilityWords, $artifactTypes, $artistNames, $battleTypes,
            $cardNames, $cardTypes, $creatureTypes, $enchantmentTypes,
            $flavorWords, $keywordAbilities, $keywordActions, $landTypes,
            $loyalties, $planeswalkerTypes, $powers, $spellTypes,
            $supertypes, $toughnesses, $watermarks, $wordBank,
        ]
    }

    private let cache: Storage<String, Data>? = {
        let disk = try? DiskStorage<String, Data>(
            config: .init(name: "scryfall-catalogs", expiry: .days(30)),
            fileManager: .default,
            transformer: .passthrough,
        )
        return disk.map {
            Storage(
                hybridStorage: HybridStorage(
                    memoryStorage: .init(config: .init(expiry: .days(1))),
                    diskStorage: $0,
                ),
            )
        }
    }()

    private var didHydrate = false

    @discardableResult
    public func dumpCaches() -> Bool {
        do {
            try cache?.removeAll()
            return true
        } catch {
            logger.error("failed to dump cache with error=\(error)")
            return false
        }
    }

    public func hydrate() async {
        guard !isRunningTests() else {
            logger.warning("skipping ScryfallCatalogs initialization in test environment")
            return
        }

        guard let cache else {
            logger.warning("cache is nil; skipping hydration")
            return
        }

        guard !didHydrate else {
            logger.warning("hydrate() called more than once; skipping")
            return
        }

        didHydrate = true

        for blob in allBlobs {
            blob.storage = cache
        }

        let client = ScryfallClient(logger: logger)

        for type in CatalogType.allCases {
            await fetch(type.rawValue, expiry: type == .cardNames ? .days(2) : nil) {
                try await client.getCatalog(catalogType: type).data
            }
        }

        await fetch("sets") {
            let sets = try await client.getSets().data
            return Dictionary(uniqueKeysWithValues: sets.map { (SetCode($0.code), $0) })
        }
        await fetch("symbology") {
            let symbols = try await client.getSymbology().data
            return Dictionary(uniqueKeysWithValues: symbols.map { (SymbolCode($0.symbol), $0) })
        }

        if let symbology = symbology.map({ Array($0.values) }) {
            await fetch("symbolSvgs") { await fetchSymbolSvgs(symbols: symbology) }
        }

        await fetch("artTags") { try await fetchTags(matchingHrefPrefix: "/search?q=art") }
        await fetch("oracleTags") { try await fetchTags(matchingHrefPrefix: "/search?q=oracletag") }
    }

    private func fetch<T: Codable>(_ key: String, expiry: Expiry? = nil, using fetcher: () async throws -> T) async {
        guard let cache else { return }

        // Cache.object(forKey:) throws StorageError.notFound or .expired if unavailable.
        if let existing = try? cache.object(forKey: key) {
            if (try? jsonDecoder.decode(T.self, from: existing)) != nil {
                logger.info("already have valid cached value for key=\(key); not fetching")
                catalogChangeNonce += 1
                return
            }

            logger.warning("cached value for key=\(key) could not be parsed; will re-fetch")

            do {
                try cache.removeObject(forKey: key)
            } catch {
                logger.warning("failed to proactively remove cache entry for key=\(key); continuing error=\(error)")
            }
        }

        let result: T
        do {
            result = try await fetcher()
        } catch {
            logger.error("error fetching data for key=\(key) from Scryfall; will continue without it error=\(error)")
            return
        }

        do {
            let data = try jsonEncoder.encode(result)
            try cache.setObject(data, forKey: key, expiry: expiry)
            catalogChangeNonce += 1
        } catch {
            logger.error("error caching value for key=\(key) error=\(error)")
            return
        }

        logger.info("fetched and cached value for key=\(key)")
    }

    private func fetchSymbolSvgs(symbols: [Card.Symbol]) async -> [SymbolCode: Data] {
        logger.info("fetching count=\(symbols.count) symbol SVGs")

        var result: [SymbolCode: Data] = [:]
        let batchSize = 10
        let symbolArray = Array(symbols)

        // n.b. the documentation at https://scryfall.com/docs/api says that the servers at
        // *.scryfall.io do NOT have rate limits, so we'll just limit ourselves to avoid having
        // an unreasonable amount of network traffic/async tasks that we have to manage.
        for batchStart in stride(from: 0, to: symbolArray.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, symbolArray.count)
            let batch = symbolArray[batchStart..<batchEnd]

            await withTaskGroup(of: (SymbolCode, Data)?.self) { group in
                for symbol in batch {
                    group.addTask {
                        if let svgUri = symbol.svgUri,
                            let url = URL(string: svgUri) {
                            logger.debug("fetching SVG for symbol=\(symbol.symbol) from svgUri=\(svgUri)")

                            var data: Data
                            var response: URLResponse
                            do {
                                (data, response) = try await URLSession.shared.data(from: url)
                            } catch {
                                // FIXME: This will be broken until ALL the SVGs expire.
                                logger.warning("failed to fetch symbol SVG for symbol=\(symbol.symbol) from svgUri=\(svgUri); this symbol will not render properly error=\(error)")
                                return nil
                            }

                            guard let httpResponse = response as? HTTPURLResponse else {
                                logger.error("SVG for symbol=\(symbol.symbol) from svgUri=\(svgUri) response was not a HTTPURLResponse")
                                return nil
                            }

                            guard (200...299).contains(httpResponse.statusCode), !data.isEmpty else {
                                logger.error("invalid response fetching SVG for symbol=\(symbol.symbol) from svgUri=\(svgUri) code=\(httpResponse.statusCode) length=\(data.count)")
                                return nil
                            }

                            if String(data: data, encoding: .utf8) == nil {
                                logger.error("SVG data for symbol=\(symbol.symbol) from svgUri=\(svgUri) is not valid UTF-8")
                                return nil
                            }

                            return (SymbolCode(symbol.symbol), data)
                        } else {
                            // FIXME: This will be broken until ALL the SVGs expire.
                            logger.warning("SVG for symbol=\(symbol.symbol) had no URI or an invalid URI svgUri=\(symbol.svgUri ?? "nil")")
                            return nil
                        }
                    }
                }

                for await fetchedResult in group {
                    if let (symbolCode, data) = fetchedResult {
                        result[symbolCode] = data
                    }
                }
            }
        }

        return result
    }

    private func fetchTags(matchingHrefPrefix hrefPrefix: String) async throws -> [String] {
        let url = URL(string: "https://scryfall.com/docs/tagger-tags")!
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let statusCode = (response as? HTTPURLResponse)?.statusCode ?? -1
            throw URLError(
                .badServerResponse,
                userInfo: [
                    NSURLErrorFailingURLErrorKey: url,
                    NSLocalizedDescriptionKey: "bad server response code=\(statusCode)",
                ]
            )
        }

        guard let html = String(data: data, encoding: .utf8) else {
            throw URLError(
                .cannotDecodeContentData,
                userInfo: [
                    NSURLErrorFailingURLErrorKey: url,
                    NSLocalizedDescriptionKey: "failed to decode HTML as UTF-8",
                ]
            )
        }

        let document = try SwiftSoup.parse(html)
        let anchors = try document.select("a[href^=\(hrefPrefix)]")
        return try anchors.map { try $0.text() }.filter { !$0.isEmpty }.sorted()
    }

    // There's got to be a better way to do this...
    subscript(catalogType: Catalog.`Type`) -> [String]? {
        switch catalogType {
        case .abilityWords: abilityWords
        case .artifactTypes: artifactTypes
        case .artistNames: artistNames
        case .battleTypes: battleTypes
        case .cardNames: cardNames
        case .cardTypes: cardTypes
        case .creatureTypes: creatureTypes
        case .enchantmentTypes: enchantmentTypes
        case .flavorWords: flavorWords
        case .keywordAbilities: keywordAbilities
        case .keywordActions: keywordActions
        case .landTypes: landTypes
        case .loyalties: loyalties
        case .planeswalkerTypes: planeswalkerTypes
        case .powers: powers
        case .spellTypes: spellTypes
        case .supertypes: supertypes
        case .toughnesses: toughnesses
        case .watermarks: watermarks
        case .wordBank: wordBank
        }
    }
}
