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
    struct SymbolCode: Equatable, Hashable, Sendable, Codable {
        let normalized: String
        
        init(_ symbol: String) {
            let trimmed = symbol.trimmingCharacters(in: .whitespaces).uppercased()
            let braced = trimmed.hasPrefix("{") && trimmed.hasSuffix("}")
                ? trimmed
                : "{\(trimmed)}"
            self.normalized = braced
        }
    }
    
    struct SetCode: Equatable, Hashable, Sendable, Codable {
        let normalized: String
        
        init(_ set: String) {
            self.normalized = set.trimmingCharacters(in: .whitespaces).uppercased()
        }
    }
    
    // MARK: - Singleton

    public static let shared = ScryfallMetadataCache()

    // MARK: - Private Properties

    private let scryfallClient = ScryfallClient()
    private let symbolCache: HybridCache<String, [SymbolCode: Card.Symbol]>
    private let setCache: HybridCache<String, [SetCode: MTGSet]>

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

    public func symbol(_ symbol: SymbolCode) async -> Result<Card.Symbol, ScryfallMetadataError> {
        let allSymbolMetadata: [SymbolCode: Card.Symbol]
        do {
            allSymbolMetadata = try await symbolCache.get(forKey: "symbology") {
                let allSymbols = try await self.fetchAllPages {
                    try await scryfallClient.getSymbology()
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
                let allSets = try await self.fetchAllPages {
                    try await scryfallClient.getSets()
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
