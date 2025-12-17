//
//  ScryfallMetadataCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//
import Foundation
import ScryfallKit

actor ScryfallMetadataCache {
    // MARK: - Singleton

    public static let shared = ScryfallMetadataCache()

    // MARK: - Private Properties

    private let scryfallClient = ScryfallClient()
    private let symbolCache: HybridCache<String, [String: Card.Symbol]>
    private let setCache: HybridCache<String, [String: MTGSet]>

    private init() {
        symbolCache = HybridCache(
            name: "ScryfallSymbols",
            expirationDays: 30,
        )

        setCache = HybridCache(
            name: "ScryfallSets",
            expirationDays: 1,
        )
    }

    // MARK: - Public Methods

    public func symbol(_ symbol: String) async -> Result<Card.Symbol, Error> {
        let cacheKey = "symbology"

        do {
            // Try to retrieve from cache, or fetch and cache if not found
            let symbolDict = try await symbolCache.get(forKey: cacheKey) {
                // Fetch from Scryfall
                let symbolList = try await scryfallClient.getSymbology()
                
                // Convert array to dictionary keyed by symbol notation
                return Dictionary(uniqueKeysWithValues: symbolList.data.map { ($0.symbol, $0) })
            }

            // Find the requested symbol
            guard let foundSymbol = symbolDict[symbol] else {
                throw NSError(
                    domain: "ScryfallMetadataCache",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Symbol '\(symbol)' not found"]
                )
            }

            return .success(foundSymbol)
        } catch {
            return .failure(error)
        }
    }

    public func set(_ setCode: String) async -> Result<MTGSet, Error> {
        let cacheKey = "sets"
        let normalizedCode = setCode.lowercased()

        do {
            // Try to retrieve from cache, or fetch and cache if not found
            let setDict = try await setCache.get(forKey: cacheKey) {
                // Fetch from Scryfall
                let setList = try await scryfallClient.getSets()
                
                // Convert array to dictionary keyed by normalized (lowercased) set code
                return Dictionary(uniqueKeysWithValues: setList.data.map { ($0.code.lowercased(), $0) })
            }

            // Find the requested set
            guard let foundSet = setDict[normalizedCode] else {
                throw NSError(
                    domain: "ScryfallMetadataCache",
                    code: 404,
                    userInfo: [NSLocalizedDescriptionKey: "Set '\(setCode)' not found"]
                )
            }

            return .success(foundSet)
        } catch {
            return .failure(error)
        }
    }
}
