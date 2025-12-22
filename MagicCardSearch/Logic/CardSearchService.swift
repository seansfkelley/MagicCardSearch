//
//
//  CardSearchService.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation
import ScryfallKit

@MainActor
class CardSearchService {
    private static let webBaseURL = "https://scryfall.com/search"
    
    private let client: ScryfallClient
    
    init() {
        self.client = ScryfallClient(networkLogLevel: .minimal)
    }
    
    func search(filters: [SearchFilter], config: SearchConfiguration) async throws -> SearchResults {
        let queryString = filters.map { $0.description }.joined(separator: " ")
        
        guard !queryString.isEmpty else {
            return SearchResults(cards: [], totalCount: 0, nextPageUrl: nil, warnings: [])
        }
        
        do {
            let result = try await client.searchCards(
                query: queryString,
                unique: config.uniqueMode.toScryfallKitUniqueMode(),
                order: config.sortField.toScryfallKitSortMode(),
                sortDirection: config.sortOrder.toScryfallKitSortDirection()
            )
            
            return SearchResults(
                cards: result.data,
                totalCount: result.totalCards ?? result.data.count,
                nextPageUrl: result.nextPage,
                warnings: result.warnings ?? []
            )
        } catch let scryfallError as ScryfallKitError {
            // When searching for cards, a 404 means "no results found", not an actual error
            if case .scryfallError(let error) = scryfallError, error.status == 404 {
                return SearchResults(cards: [], totalCount: 0, nextPageUrl: nil, warnings: [])
            }
            // Re-throw other Scryfall errors
            throw scryfallError
        }
    }
    
    nonisolated func fetchNextPage(from urlString: String) async throws -> SearchResults {
        // ScryfallKit doesn't expose a direct "fetch from URL" method,
        // so we need to parse the URL and extract parameters
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw SearchError.invalidURL
        }
        
        // Extract query parameters
        let query = queryItems.first { $0.name == "q" }?.value ?? ""
        let page = queryItems.first { $0.name == "page" }.flatMap { Int($0.value ?? "") }
        
        // Extract optional parameters
        let uniqueValue = queryItems.first { $0.name == "unique" }?.value
        let unique = uniqueValue.flatMap { UniqueMode(rawValue: $0) }
        
        let orderValue = queryItems.first { $0.name == "order" }?.value
        let order = orderValue.flatMap { SortMode(rawValue: $0) }
        
        let dirValue = queryItems.first { $0.name == "dir" }?.value
        let sortDirection = dirValue.flatMap { SortDirection(rawValue: $0) }
        
        do {
            let result = try await client.searchCards(
                query: query,
                unique: unique,
                order: order,
                sortDirection: sortDirection,
                page: page
            )
            
            return SearchResults(
                cards: result.data,
                totalCount: result.totalCards ?? result.data.count,
                nextPageUrl: result.nextPage,
                warnings: result.warnings ?? []
            )
        } catch let scryfallError as ScryfallKitError {
            // When paginating search results, a 404 means "no more results", not an actual error
            if case .scryfallError(let error) = scryfallError, error.status == 404 {
                return SearchResults(cards: [], totalCount: 0, nextPageUrl: nil, warnings: [])
            }
            // Re-throw other Scryfall errors
            throw scryfallError
        }
    }
    
    func fetchCard(byId id: UUID) async throws -> Card {
        return try await client.getCard(identifier: .scryfallID(id: id.uuidString))
    }
    
    // TODO: This is actually searching for all prints, not as generic as it sounds.
    func searchCardsByOracleId(_ oracleId: String) async throws -> [Card] {
        var allCards: [Card] = []
        var nextPageUrl: String?
        
        // Fetch first page
        let firstResult = try await client.searchCards(query: "oracleID:\(oracleId)", unique: .prints, order: .released, includeExtras: true)
        allCards.append(contentsOf: firstResult.data)
        nextPageUrl = firstResult.nextPage
        
        // Fetch remaining pages if they exist
        while let pageURL = nextPageUrl {
            let pageResult = try await fetchNextPage(from: pageURL)
            allCards.append(contentsOf: pageResult.cards)
            nextPageUrl = pageResult.nextPageUrl
        }
        
        return allCards
    }
    
    /// Searches for cards using a raw Scryfall query string
    /// - Parameter query: The raw Scryfall query string (e.g., "oracleid:abc123 frame:old")
    /// - Returns: All matching cards across all pages
    func searchByRawQuery(_ query: String) async throws -> [Card] {
        var allCards: [Card] = []
        var nextPageUrl: String?
        
        do {
            // Fetch first page
            let firstResult = try await client.searchCards(query: query, unique: .prints, order: .released, includeExtras: true)
            allCards.append(contentsOf: firstResult.data)
            nextPageUrl = firstResult.nextPage
            
            // Fetch remaining pages if they exist
            while let pageURL = nextPageUrl {
                let pageResult = try await fetchNextPage(from: pageURL)
                allCards.append(contentsOf: pageResult.cards)
                nextPageUrl = pageResult.nextPageUrl
            }
        } catch let scryfallError as ScryfallKitError {
            // When searching for cards, a 404 means "no results found", not an actual error
            if case .scryfallError(let error) = scryfallError, error.status == 404 {
                return []
            }
            // Re-throw other Scryfall errors
            throw scryfallError
        }
        
        return allCards
    }
    
    static func buildSearchURL(filters: [SearchFilter], config: SearchConfiguration, forAPI: Bool) -> URL? {
        let queryString = filters.map { $0.description }.joined(separator: " ")
        
        guard !queryString.isEmpty else {
            return nil
        }
        
        // For sharing, always build the web URL
        let baseURL = webBaseURL
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: queryString),
            URLQueryItem(name: "unique", value: config.uniqueMode.apiValue),
            URLQueryItem(name: "order", value: config.sortField.apiValue),
            URLQueryItem(name: "dir", value: config.sortOrder.apiValue),
        ]
        
        return components.url
    }
}

// MARK: - Search Errors

enum SearchError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid search URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "Server error: \(statusCode)"
        }
    }
}
