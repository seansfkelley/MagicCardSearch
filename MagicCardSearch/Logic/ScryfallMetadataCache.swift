//
//  ScryfallMetadataCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//
import Foundation
import ScryfallKit
import Logging

private let logger = Logger(label: "ScryfallMetadataCache")

struct SymbolCode: Equatable, Hashable, Sendable, Codable, CustomStringConvertible {
    let normalized: String
    
    init(_ symbol: String) {
        let trimmed = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        let braced = trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
            ? trimmed
            : "{\(trimmed)}"
        self.normalized = braced
    }
    
    var description: String {
        "Symbol\(normalized)"
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
    case noSuchValue(String)
}

actor ScryfallMetadataCache {
    // MARK: - Singleton

    public static let shared = ScryfallMetadataCache()
    public static let symbolSvgCache: any Cache<SymbolCode, Data> = HybridCache(
        name: "SymbolSvgs",
        expiration: .interval(30 * 24 * 60 * 60)
    ) ?? MemoryCache(expiration: .never)

    // MARK: - Private Properties

    private let scryfallClient = ScryfallClient()
    private var symbolCache: any Cache<String, [SymbolCode: Card.Symbol]>
    private var setCache: any Cache<String, [SetCode: MTGSet]>

    private init() {
        symbolCache = HybridCache(
            name: "ScryfallSymbols",
            expiration: .interval(30 * 24 * 60 * 60),
        ) ?? MemoryCache(expiration: .never)

        setCache = HybridCache(
            name: "ScryfallSets",
            expiration: .interval(24 * 60 * 60),
        ) ?? MemoryCache(expiration: .never)
    }

    // MARK: - Public Methods
    
    /// Prefetches all symbology data into the cache
    /// - Returns: Result indicating success or failure of the prefetch operation
    @discardableResult
    public func prefetchSymbology() async -> Result<Void, ScryfallMetadataError> {
        do {
            let symbolDict = try await symbolCache.get(forKey: "symbology") {
                logger.info("Fetching symbology...")
                let allSymbols = try await self.fetchAllPages {
                    try await self.scryfallClient.getSymbology()
                }
                return Dictionary(
                    uniqueKeysWithValues: allSymbols.map { (SymbolCode($0.symbol), $0) }
                )
            }
            
            // Prefetch SVGs for all symbols
            logger.info("Prefetching \(symbolDict.count) symbol SVGs...")
            await prefetchSymbolSvgs(from: symbolDict)
            
            return .success(())
        } catch {
            return .failure(.errorLoadingData(error))
        }
    }
    
    /// Prefetches all set data into the cache
    /// - Returns: Result indicating success or failure of the prefetch operation
    @discardableResult
    public func prefetchSets() async -> Result<Void, ScryfallMetadataError> {
        do {
            _ = try await setCache.get(forKey: "sets") {
                logger.info("Fetching sets...")
                let allSets = try await self.fetchAllPages {
                    try await self.scryfallClient.getSets()
                }
                return Dictionary(uniqueKeysWithValues: allSets.map { (SetCode($0.code), $0) })
            }
            return .success(())
        } catch {
            return .failure(.errorLoadingData(error))
        }
    }

    public func symbol(_ symbol: SymbolCode) async -> Result<Card.Symbol, ScryfallMetadataError> {
        let allSymbolMetadata: [SymbolCode: Card.Symbol]
        do {
            allSymbolMetadata = try await symbolCache.get(forKey: "symbology") {
                logger.info("Fetching symbology...")
                let allSymbols = try await self.fetchAllPages {
                    try await self.scryfallClient.getSymbology()
                }
                return Dictionary(
                    uniqueKeysWithValues: allSymbols.map { (SymbolCode($0.symbol), $0) }
                )
            }
        } catch {
            return .failure(.errorLoadingData(error))
        }

        if let foundSymbol = allSymbolMetadata[symbol] {
            return .success(foundSymbol)
        } else {
            return .failure(.noSuchValue(symbol.normalized))
        }
    }

    public func set(_ setCode: SetCode) async -> Result<MTGSet, ScryfallMetadataError> {
        let allSetMetadata: [SetCode: MTGSet]
        do {
            allSetMetadata = try await setCache.get(forKey: "sets") {
                logger.info("Fetching sets...")
                let allSets = try await self.fetchAllPages {
                    try await self.scryfallClient.getSets()
                }
                return Dictionary(uniqueKeysWithValues: allSets.map { (SetCode($0.code), $0) })
            }
        } catch {
            return .failure(.errorLoadingData(error))
        }

        if let foundSet = allSetMetadata[setCode] {
            return .success(foundSet)
        } else {
            return .failure(.noSuchValue(setCode.normalized))
        }
    }
    
    // MARK: - Private Methods
    
    private func prefetchSymbolSvgs(from symbols: [SymbolCode: Card.Symbol]) async {
        let batchSize = 10
        let symbolArray = Array(symbols)
        
        // n.b. the documentation at https://scryfall.com/docs/api says that the servers at
        // *.scryfall.io do NOT have rate limits, so we'll just limit ourselves to avoid having
        // an unreasonable amount of network traffic/async tasks that we have to manage.
        for batchStart in stride(from: 0, to: symbolArray.count, by: batchSize) {
            let batchEnd = min(batchStart + batchSize, symbolArray.count)
            let batch = symbolArray[batchStart..<batchEnd]
            
            await withTaskGroup(of: Void.self) { group in
                for (symbolCode, symbolData) in batch {
                    group.addTask {
                        do {
                            _ = try await Self.symbolSvgCache.get(forKey: symbolCode) {
                                if let svgUri = symbolData.svgUri,
                                   let url = URL(string: svgUri) {
                                    logger.debug("Fetching symbol SVG", metadata: [
                                        "symbolCode": "\(symbolCode)",
                                        "svgUri": "\(svgUri)",
                                    ])
                                    let (data, _) = try await URLSession.shared.data(from: url)
                                    return data
                                } else {
                                    throw ScryfallMetadataError.errorLoadingData(nil)
                                }
                            }
                        } catch {
                            logger.warning("Failed to fetch symbol SVG; this symbol will not render properly", metadata: [
                                "symbolCode": "\(symbolCode)",
                                "error": "\(error)",
                            ])
                        }
                    }
                }
            }
        }
        
        logger.info("Completed SVG prefetch")
    }
    
    /// Fetches all pages from an initial ObjectList request and returns a flat array
    /// - Parameter initialRequest: A closure that performs the initial ScryfallClient request
    /// - Returns: An array containing all items from all pages
    private func fetchAllPages<T: Codable>(
        initialRequest: () async throws -> ObjectList<T>
    ) async throws -> [T] {
        var allItems: [T] = []
        var currentList = try await initialRequest()
        allItems.append(contentsOf: currentList.data)
        
        // Fetch additional pages if they exist
        while let nextPageURL = currentList.nextPage {
            currentList = try await self.fetchObjectList(from: nextPageURL)
            allItems.append(contentsOf: currentList.data)
        }
        
        return allItems
    }
    
    /// Fetches a Scryfall ObjectList from a URL using URLSession and ScryfallKit's ObjectList type
    private func fetchObjectList<T: Codable>(from urlString: String) async throws -> ObjectList<T> {
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "ScryfallMetadataCache",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"]
            )
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ScryfallMetadataCache",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
            )
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "ScryfallMetadataCache",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(ObjectList<T>.self, from: data)
    }
}
