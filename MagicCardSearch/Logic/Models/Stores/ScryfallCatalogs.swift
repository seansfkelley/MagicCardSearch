import Foundation
import ScryfallKit
import OSLog
import SQLiteData
import SwiftSoup

private let logger = Logger(subsystem: "MagicCardSearch", category: "ScryfallCatalogs")

private let oneDay: TimeInterval = 60 * 60 * 24
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

// swiftlint:disable attributes
@MainActor
@Observable
class ScryfallCatalogs {
    @ObservationIgnored
    @TransformedBlob("sets", { data in
        let parsed = try jsonDecoder.decode([MTGSet].self, from: data)
        return Dictionary(uniqueKeysWithValues: parsed.map { (SetCode($0.code), $0) })
    })
    public var sets: [SetCode: MTGSet]?

    @ObservationIgnored
    @TransformedBlob("symbology", { data in
        let parsed = try jsonDecoder.decode([Card.Symbol].self, from: data)
        return Dictionary(uniqueKeysWithValues: parsed.map { (SymbolCode($0.symbol), $0) })
    })
    public var symbology: [SymbolCode: Card.Symbol]?

    @ObservationIgnored
    @TransformedBlob("symbolSvgs")
    public var symbolSvgs: [SymbolCode: Data]?

    @ObservationIgnored
    @TransformedBlob("artTags")
    public var artTags: [String]?

    @ObservationIgnored
    @TransformedBlob("oracleTags")
    public var oracleTags: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.abilityWords.rawValue)
    public var abilityWords: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.artifactTypes.rawValue)
    public var artifactTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.artistNames.rawValue)
    public var artistNames: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.battleTypes.rawValue)
    public var battleTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.cardNames.rawValue)
    public var cardNames: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.cardTypes.rawValue)
    public var cardTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.creatureTypes.rawValue)
    public var creatureTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.enchantmentTypes.rawValue)
    public var enchantmentTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.flavorWords.rawValue)
    public var flavorWords: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.keywordAbilities.rawValue)
    public var keywordAbilities: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.keywordActions.rawValue)
    public var keywordActions: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.landTypes.rawValue)
    public var landTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.loyalties.rawValue)
    public var loyalties: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.planeswalkerTypes.rawValue)
    public var planeswalkerTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.powers.rawValue)
    public var powers: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.spellTypes.rawValue)
    public var spellTypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.supertypes.rawValue)
    public var supertypes: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.toughnesses.rawValue)
    public var toughnesses: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.watermarks.rawValue)
    public var watermarks: [String]?

    @ObservationIgnored
    @TransformedBlob(CatalogType.wordBank.rawValue)
    public var wordBank: [String]?

    private let database: any DatabaseWriter

    public init(database: DatabaseWriter) {
        self.database = database
    }

    public func hydrate() async {
        guard !isRunningTests() else {
            logger.warning("skipping ScryfallCatalogs initialization in test environment")
            return
        }

        let client = ScryfallClient(logger: logger)

        for type in CatalogType.allCases {
            await fetch(type.rawValue) {
                try await client.getCatalog(catalogType: type).data
            }
        }

        await fetch("sets") { try await client.getSets().data }
        await fetch("symbology") { try await client.getSymbology().data }

        let symbology: [Card.Symbol]?
        do {
            symbology = try await database.read { db in
                if let blob = try (BlobEntry.where { $0.key.eq("symbology") }.fetchOne(db)) {
                    try jsonDecoder.decode([Card.Symbol].self, from: blob.value)
                } else {
                    nil
                }
            }
        } catch {
            symbology = nil
            logger.warning("failed to load or parse symbology; will not attempt to load SVGs error=\(error)")
        }

        if let symbology {
            await fetch("symbolSvgs") { await fetchSymbolSvgs(symbols: symbology) }
        }

        await fetch("artTags") { try await fetchTags(matchingHrefPrefix: "/search?q=art") }
        await fetch("oracleTags") { try await fetchTags(matchingHrefPrefix: "/search?q=oracletag") }
    }

    private func fetch<T: Codable>(_ key: String, expiringAfterDays expirationInDays: Int = 30, using fetcher: () async throws -> T) async {
        let existing: BlobEntry?
        do {
            existing = try await database.read { db in
                try BlobEntry.where { $0.key.eq(key) }.fetchOne(db)
            }
        } catch {
            existing = nil
            logger.warning("failed while reading blob for key=\(key) from database; will re-fetch error=\(error)")
        }

        if let existing {
            if existing.insertedAt >= Date(timeIntervalSinceNow: -Double(expirationInDays) * oneDay) {
                do {
                    _ = try jsonDecoder.decode(T.self, from: existing.value)
                    logger.info("already have valid blob for key=\(key); not fetching")
                    return
                } catch {
                    logger.warning("blob for key=\(key) existed but could not be parsed; will re-fetch error=\(error)")
                }
            } else {
                logger.info("blob for key=\(key) existed but is expired; will re-fetch")
            }
        }

        let result: T
        do {
            result = try await fetcher()
        } catch {
            logger.error("error fetching blob data for key=\(key) from Scryfall; will continue without error=\(error)")
            return
        }

        do {
            let value = try jsonEncoder.encode(result)

            _ = try await database.write { db in
                try BlobEntry
                    .insert { BlobEntry(key: key, value: value) }
                    .execute(db)
            }
        } catch {
            logger.error("error writing blob for key=\(key) to store error=\(error)")
            return
        }

        logger.info("fetched and cached blob for key=\(key)")
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
// swiftlint:enable attributes
