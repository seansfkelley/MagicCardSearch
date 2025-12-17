//
//  ScryfallMetadataCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//
import Foundation
import ScryfallKit

enum ScryfallMetadataError: Error {
    case errorLoadingData(Error)
    case noSuchValue(String)
}

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
            expiration: .interval(30 * 24 * 60 * 60)  // 30 days
        )!

        setCache = HybridCache(
            name: "ScryfallSets",
            expiration: .interval(24 * 60 * 60)  // 1 day
        )!
    }

    // MARK: - Public Methods

    public func symbol(_ symbol: String) async -> Result<Card.Symbol, ScryfallMetadataError> {
        let allSymbolMetadata: [String: Card.Symbol]
        do {
            allSymbolMetadata = try await symbolCache.get(forKey: "symbology") {
                let allSymbols = try await self.fetchAllPages {
                    try await scryfallClient.getSymbology()
                }
                return Dictionary(
                    uniqueKeysWithValues: allSymbols.map { ($0.symbol.uppercased(), $0) },
                )
            }
        } catch {
            return .failure(.errorLoadingData(error))
        }
        
        let normalizedSymbol = symbol.trimmingCharacters(in: .whitespaces).uppercased()
        let withBraces = normalizedSymbol.hasPrefix("{") && normalizedSymbol.hasSuffix("}")
            ? normalizedSymbol
            : "{\(normalizedSymbol)}"

        if let foundSymbol = allSymbolMetadata[normalizedSymbol] {
            return .success(foundSymbol)
        } else {
            return .failure(.noSuchValue(normalizedSymbol))
        }
    }

    public func set(_ setCode: String) async -> Result<MTGSet, ScryfallMetadataError> {
        let allSetMetadata: [String: MTGSet]
        do {
            allSetMetadata = try await setCache.get(forKey: "sets") {
                let allSets = try await self.fetchAllPages {
                    try await scryfallClient.getSets()
                }
                return Dictionary(uniqueKeysWithValues: allSets.map { ($0.code.uppercased(), $0) })
            }
        } catch {
            return .failure(.errorLoadingData(error))
        }

        if let set = allSetMetadata[setCode.uppercased()] {
            return .success(set)
        } else {
            return .failure(.noSuchValue(setCode.uppercased()))
        }
    }
    
    // MARK: - Private Methods
    
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
