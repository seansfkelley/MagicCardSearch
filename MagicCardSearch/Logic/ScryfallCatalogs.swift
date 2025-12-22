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
    @MainActor var isOversized: Bool? {
        if let symbol = ScryfallCatalogs.shared.symbols[self] {
            symbol.phyrexian || symbol.hybrid
        } else {
            nil
        }
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

@MainActor
final class ScryfallCatalogs {
    // MARK: - Singleton

    public static let shared = ScryfallCatalogs()

    // MARK: - Public Properties

    public var sets: [SetCode: MTGSet] = [:]
    public var symbols: [SymbolCode: Card.Symbol] = [:]
    public var symbolSvg: [SymbolCode: Data] = [:]
    public func catalog(_ catalogType: Catalog.`Type`) -> Set<String>? {
        return stringCache[catalogType]
    }

    // MARK: - Private Properties

    private let scryfallClient = ScryfallClient()
    private var setCache: any Cache<String, [SetCode: MTGSet]>
    private var symbolCache: any Cache<String, [SymbolCode: Card.Symbol]>
    private var stringCache: any Cache<Catalog.`Type`, Set<String>>
    private var symbolSvgCache: any Cache<SymbolCode, Data>
    
    private init() {
        setCache =
            HybridCache(
                name: "ScryfallSets",
                expiration: .interval(24 * 60 * 60),
            ) ?? MemoryCache(expiration: .never)

        symbolCache =
            HybridCache(
                name: "ScryfallSymbols",
                expiration: .interval(30 * 24 * 60 * 60),
            ) ?? MemoryCache(expiration: .never)

        stringCache =
            HybridCache(
                name: "ScryfallStrings",
                expiration: .interval(30 * 24 * 60 * 60)
            ) ?? MemoryCache(expiration: .never)

        symbolSvgCache =
            HybridCache(
                name: "ScryfallSymbolSvgs",
                expiration: .interval(30 * 24 * 60 * 60)
            ) ?? MemoryCache(expiration: .never)
    }

    // MARK: - Public Methods

    /// Prefetches all symbology data into the cache
    /// - Returns: Result indicating success or failure of the prefetch operation
    @discardableResult
    public func prefetchSymbology() async -> Result<Void, ScryfallMetadataError> {
        guard !isRunningTests() else {
            logger.info("Skipping symbology prefetch in test environment")
            return .success(())
        }
        
        do {
            symbols = try await symbolCache.get(forKey: "symbology") {
                logger.info("Fetching symbology...")
                let allSymbols = try await ScryfallPagination.fetchAllPages {
                    try await self.scryfallClient.getSymbology()
                }
                return Dictionary(
                    uniqueKeysWithValues: allSymbols.map { (SymbolCode($0.symbol), $0) }
                )
            }

            await prefetchSymbolSvgs(from: symbols)

            return .success(())
        } catch {
            return .failure(.errorLoadingData(error))
        }
    }

    /// Prefetches all set data into the cache
    /// - Returns: Result indicating success or failure of the prefetch operation
    @discardableResult
    public func prefetchSets() async -> Result<Void, ScryfallMetadataError> {
        guard !isRunningTests() else {
            logger.info("Skipping sets prefetch in test environment")
            return .success(())
        }
        
        do {
            sets = try await setCache.get(forKey: "sets") {
                logger.info("Fetching sets...")
                let allSets = try await ScryfallPagination.fetchAllPages {
                    try await self.scryfallClient.getSets()
                }
                return Dictionary(uniqueKeysWithValues: allSets.map { (SetCode($0.code), $0) })
            }
            return .success(())
        } catch {
            return .failure(.errorLoadingData(error))
        }
    }

    /// Prefetches all catalog data into the cache
    /// - Returns: Result indicating success or failure of the prefetch operation
    @discardableResult
    public func prefetchCatalogs() async -> Result<Void, ScryfallMetadataError> {
        guard !isRunningTests() else {
            logger.info("Skipping catalogs prefetch in test environment")
            return .success(())
        }
        
        do {
            logger.info("Fetching catalogs...")

            // Workaround for the compiler being unhappy about Catalog.`Type`.allCases.
            typealias CatalogType = Catalog.`Type`
            for catalogType in CatalogType.allCases {
                _ = try await stringCache.get(forKey: catalogType) {
                    logger.debug("Fetching catalog", metadata: ["type": "\(catalogType.rawValue)"])
                    let catalog = try await self.scryfallClient.getCatalog(catalogType: catalogType)
                    return Set(catalog.data)
                }
            }

            return .success(())
        } catch {
            return .failure(.errorLoadingData(error))
        }
    }

    /// Pre-fetches Scryfall metadata (symbols, sets, and catalogs) in the background
    public func prefetchAll() async {
        await withTaskGroup(of: Void.self) { group in
            group.addTask {
                _ = await self.prefetchSymbology()
            }

            group.addTask {
                _ = await self.prefetchSets()
            }

            group.addTask {
                _ = await self.prefetchCatalogs()
            }
        }
    }

    // MARK: - Private Methods

    // swiftlint:disable:next function_body_length
    private func prefetchSymbolSvgs(from symbols: [SymbolCode: Card.Symbol]) async {
        logger.info("Prefetching \(symbols.count) symbol SVGs...")

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
                            let data = try await self.symbolSvgCache.get(forKey: symbolCode) {
                                if let svgUri = symbolData.svgUri,
                                    let url = URL(string: svgUri) {
                                    logger.debug("Fetching symbol SVG", metadata: [
                                        "symbolCode": "\(symbolCode)",
                                        "svgUri": "\(svgUri)",
                                    ])
                                    let (data, response) = try await URLSession.shared.data(from: url)
                                    
                                    // Validate the response and data
                                    guard let httpResponse = response as? HTTPURLResponse,
                                          (200...299).contains(httpResponse.statusCode),
                                          !data.isEmpty else {
                                        logger.error("Invalid SVG response", metadata: [
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
                                "Failed to fetch symbol SVG; this symbol will not render properly",
                                metadata: [
                                    "symbolCode": "\(symbolCode)",
                                    "error": "\(error)",
                                ]
                            )
                            return nil
                        }
                    }
                }

                for await result in group {
                    if let (symbolCode, data) = result {
                        symbolSvg[symbolCode] = data
                    }
                }
            }
        }

        logger.info("Completed SVG prefetch")
    }
}
