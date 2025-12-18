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
    
    /// Nil, if the metadata telling us this is not yet loaded.
    @MainActor var isOversized: Bool? {
        if let symbol = ScryfallMetadataCache.shared.symbols[self] {
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
final class ScryfallMetadataCache {
    // MARK: - Singleton

    public static let shared = ScryfallMetadataCache()
    
    // MARK: - Public Properties
    
    public var sets: [SetCode: MTGSet] = [:]
    public var symbols: [SymbolCode: Card.Symbol] = [:]
    public var symbolSvg: [SymbolCode: Data] = [:]

    // MARK: - Private Properties
    
    private let scryfallClient = ScryfallClient()
    private var setCache: any Cache<String, [SetCode: MTGSet]>
    private var symbolCache: any Cache<String, [SymbolCode: Card.Symbol]>
    private var symbolSvgCache: any Cache<SymbolCode, Data>

    private init() {
        setCache = HybridCache(
            name: "ScryfallSets",
            expiration: .interval(24 * 60 * 60),
        ) ?? MemoryCache(expiration: .never)
        
        symbolCache = HybridCache(
            name: "ScryfallSymbols",
            expiration: .interval(30 * 24 * 60 * 60),
        ) ?? MemoryCache(expiration: .never)
        
        symbolSvgCache = HybridCache(
            name: "ScryfallSymbolSvgs",
            expiration: .interval(30 * 24 * 60 * 60)
        ) ?? MemoryCache(expiration: .never)
    }

    // MARK: - Public Methods
    
    /// Prefetches all symbology data into the cache
    /// - Returns: Result indicating success or failure of the prefetch operation
    @discardableResult
    public func prefetchSymbology() async -> Result<Void, ScryfallMetadataError> {
        do {
            symbols = try await symbolCache.get(forKey: "symbology") {
                logger.info("Fetching symbology...")
                let allSymbols = try await self.fetchAllPages {
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
        do {
            sets = try await setCache.get(forKey: "sets") {
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

    // MARK: - Private Methods
    
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
                                    let (data, _) = try await URLSession.shared.data(from: url)
                                    return data
                                } else {
                                    throw ScryfallMetadataError.errorLoadingData(nil)
                                }
                            }
                            return (symbolCode, data)
                        } catch {
                            logger.warning("Failed to fetch symbol SVG; this symbol will not render properly", metadata: [
                                "symbolCode": "\(symbolCode)",
                                "error": "\(error)",
                            ])
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
