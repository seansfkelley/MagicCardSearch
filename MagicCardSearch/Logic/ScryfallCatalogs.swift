//
//  ScryfallMetadataCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//
import Foundation
import Logging
import ScryfallKit

private let logger = Logger(label: "ScryfallCatalogs")

struct SymbolCode: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    let normalized: String

    init(_ symbol: String) {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        let braced =
            trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
            ? trimmed
            : "{\(trimmed)}"
        self.normalized = braced
    }

    var description: String {
        "Symbol\(normalized)"
    }

    /// Nil, if the metadata telling us this is not yet loaded.
    var isOversized: Bool? {
        guard let symbol = ScryfallCatalogs.sync?.symbols[self] else {
            return nil
        }
        return symbol.phyrexian || symbol.hybrid
    }
}

struct SetCode: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    let normalized: String

    init(_ set: String) {
        self.normalized = set.trimmingCharacters(in: .whitespaces).uppercased()
    }

    var description: String {
        "Set[\(normalized)]"
    }
}

enum ScryfallMetadataError: Error {
    case errorLoadingData(Error?)
}

final class ScryfallCatalogs: Sendable {
    // MARK: - Singleton

    public static var sync: ScryfallCatalogs? {
        singletonLock.withLock {
            return singleton.latestValue
        }
    }

    private static let singletonLock = NSLock()
    nonisolated(unsafe) private static var singleton: LoadableResult<ScryfallCatalogs, Error> = .unloaded

    // MARK: - Public Properties

    public let sets: [SetCode: MTGSet]
    public let symbols: [SymbolCode: Card.Symbol]
    public let symbolSvg: [SymbolCode: Data]
    public let catalogs: [Catalog.`Type`: Set<String>]

    // MARK: - Initialization

    private init(
        sets: [SetCode: MTGSet],
        symbols: [SymbolCode: Card.Symbol],
        symbolSvg: [SymbolCode: Data],
        catalogs: [Catalog.`Type`: Set<String>]
    ) {
        self.sets = sets
        self.symbols = symbols
        self.symbolSvg = symbolSvg
        self.catalogs = catalogs
    }

    private convenience init() {
        self.init(sets: [:], symbols: [:], symbolSvg: [:], catalogs: [:])
    }

    // MARK: - Public Methods

    // swiftlint:disable:next function_body_length
    public static func initialize() async {
        singletonLock.withLock {
            guard case .unloaded = singleton else {
                logger.warning("ignoring request to reload ScryfallCatalogs")
                return
            }

            guard !isRunningTests() else {
                logger.info("stubbing ScryfallCatalogs initialization to be empty in test environment")
                singleton = .loaded(.init(), nil)
                return
            }

            singleton = .loading(.init(), nil)
        }

        logger.info("initializing ScryfallCatalogs...")

        let scryfallClient = ScryfallClient()

        let setCache: any Cache<String, [SetCode: MTGSet]> =
        DiskCache(
            name: "ScryfallSets",
            expiration: .interval(24 * 60 * 60)
        ) ?? MemoryCache(expiration: .never)

        let symbolCache: any Cache<String, [SymbolCode: Card.Symbol]> =
        DiskCache(
            name: "ScryfallSymbols",
            expiration: .interval(30 * 24 * 60 * 60)
        ) ?? MemoryCache(expiration: .never)

        let stringCache: any Cache<Catalog.`Type`, Set<String>> =
        DiskCache(
            name: "ScryfallStrings",
            expiration: .interval(30 * 24 * 60 * 60)
        ) ?? MemoryCache(expiration: .never)

        let symbolSvgCache: any Cache<SymbolCode, Data> =
        DiskCache(
            name: "ScryfallSymbolSvgs",
            expiration: .interval(30 * 24 * 60 * 60)
        ) ?? MemoryCache(expiration: .never)

        do {
            async let setsData = fetchSets(client: scryfallClient, cache: setCache)
            async let symbolsData = fetchSymbols(client: scryfallClient, cache: symbolCache)
            async let catalogsData = fetchCatalogs(client: scryfallClient, cache: stringCache)

            let (sets, symbols, catalogs) = try await (setsData, symbolsData, catalogsData)
            let symbolSvg = await fetchSymbolSvgs(symbols: symbols, cache: symbolSvgCache)
            
            singletonLock.withLock {
                singleton = .loaded(
                    ScryfallCatalogs(
                        sets: sets,
                        symbols: symbols,
                        symbolSvg: symbolSvg,
                        catalogs: catalogs
                    ),
                    nil,
                )
            }
            logger.info("ScryfallCatalogs initialization complete")
        } catch {
            singletonLock.withLock {
                singleton = .errored(.init(), error)
            }
            logger.error("failed to initialize ScryfallCatalogs", metadata: ["error": "\(error)"])
        }
    }

    private static func fetchSets(
        client: ScryfallClient,
        cache: any Cache<String, [SetCode: MTGSet]>
    ) async throws -> [SetCode: MTGSet] {
        try await cache.get(forKey: "sets") {
            logger.info("fetching sets...")
            let allSets = try await ScryfallPagination.fetchAllPages {
                try await client.getSets()
            }
            return Dictionary(uniqueKeysWithValues: allSets.map { (SetCode($0.code), $0) })
        }
    }

    private static func fetchSymbols(
        client: ScryfallClient,
        cache: any Cache<String, [SymbolCode: Card.Symbol]>
    ) async throws -> [SymbolCode: Card.Symbol] {
        try await cache.get(forKey: "symbology") {
            logger.info("fetching symbology...")
            let allSymbols = try await ScryfallPagination.fetchAllPages {
                try await client.getSymbology()
            }
            return Dictionary(
                uniqueKeysWithValues: allSymbols.map { (SymbolCode($0.symbol), $0) }
            )
        }
    }

    private static func fetchCatalogs(
        client: ScryfallClient,
        cache: any Cache<Catalog.`Type`, Set<String>>
    ) async throws -> [Catalog.`Type`: Set<String>] {
        logger.info("fetching catalogs...")

        var result: [Catalog.`Type`: Set<String>] = [:]
        
        // Workaround for the compiler being unhappy about Catalog.`Type`.allCases.
        typealias CatalogType = Catalog.`Type`
        for catalogType in CatalogType.allCases {
            let data = try await cache.get(forKey: catalogType) {
                logger.debug("fetching catalog", metadata: ["type": "\(catalogType.rawValue)"])
                let catalog = try await client.getCatalog(catalogType: catalogType)
                return Set(catalog.data)
            }
            result[catalogType] = data
        }
        
        return result
    }

    // swiftlint:disable:next function_body_length
    private static func fetchSymbolSvgs(
        symbols: [SymbolCode: Card.Symbol],
        cache: any Cache<SymbolCode, Data>
    ) async -> [SymbolCode: Data] {
        logger.info("fetching \(symbols.count) symbol SVGs...")

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
                for (symbolCode, symbolData) in batch {
                    group.addTask {
                        do {
                            let data = try await cache.get(forKey: symbolCode) {
                                if let svgUri = symbolData.svgUri,
                                    let url = URL(string: svgUri) {
                                    logger.debug("fetching symbol SVG", metadata: [
                                        "symbolCode": "\(symbolCode)",
                                        "svgUri": "\(svgUri)",
                                    ])
                                    let (data, response) = try await URLSession.shared.data(from: url)
                                    
                                    // Validate the response and data
                                    guard let httpResponse = response as? HTTPURLResponse,
                                          (200...299).contains(httpResponse.statusCode),
                                          !data.isEmpty else {
                                        logger.error("invalid SVG response", metadata: [
                                            "symbolCode": "\(symbolCode)",
                                            "svgUri": "\(svgUri)",
                                            "dataSize": "\(data.count)",
                                        ])
                                        throw ScryfallMetadataError.errorLoadingData(nil)
                                    }
                                    
                                    // Verify it's actually valid UTF-8 (SVG files should be)
                                    if String(data: data, encoding: .utf8) == nil {
                                        logger.error("SVG data is not valid UTF-8", metadata: [
                                            "symbolCode": "\(symbolCode)",
                                            "svgUri": "\(svgUri)",
                                            "dataSize": "\(data.count)",
                                        ])
                                        throw ScryfallMetadataError.errorLoadingData(nil)
                                    }
                                    
                                    return data
                                } else {
                                    throw ScryfallMetadataError.errorLoadingData(nil)
                                }
                            }
                            return (symbolCode, data)
                        } catch {
                            logger.warning(
                                "failed to fetch symbol SVG; this symbol will not render properly",
                                metadata: [
                                    "symbolCode": "\(symbolCode)",
                                    "error": "\(error)",
                                ]
                            )
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
}
