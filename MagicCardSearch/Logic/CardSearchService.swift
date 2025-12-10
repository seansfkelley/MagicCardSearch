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
    
    func search(filters: [SearchFilter], config: SearchConfiguration) async throws -> SearchResult {
        let queryString = filters.map { $0.queryStringWithEditingRange.0 }.joined(separator: " ")
        
        guard !queryString.isEmpty else {
            return SearchResult(cards: [], totalCount: 0, nextPageURL: nil, warnings: [])
        }
        
        let result = try await client.searchCards(
            query: queryString,
            unique: config.uniqueMode.toScryfallKitUniqueMode(),
            order: config.sortField.toScryfallKitSortMode(),
            sortDirection: config.sortOrder.toScryfallKitSortDirection()
        )
        
        return SearchResult(
            cards: result.data,
            totalCount: result.totalCards ?? result.data.count,
            nextPageURL: result.nextPage,
            warnings: result.warnings ?? []
        )
    }
    
    func fetchNextPage(from urlString: String) async throws -> SearchResult {
        // ScryfallKit doesn't expose a direct "fetch from URL" method,
        // so we need to parse the URL and extract parameters
        guard let url = URL(string: urlString),
              let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let queryItems = components.queryItems else {
            throw SearchError.invalidURL
        }
        
        // Extract query parameters
        let query = queryItems.first(where: { $0.name == "q" })?.value ?? ""
        let page = queryItems.first(where: { $0.name == "page" }).flatMap { Int($0.value ?? "") }
        
        // Extract optional parameters
        let uniqueValue = queryItems.first(where: { $0.name == "unique" })?.value
        let unique = uniqueValue.flatMap { UniqueMode(rawValue: $0) }
        
        let orderValue = queryItems.first(where: { $0.name == "order" })?.value
        let order = orderValue.flatMap { SortMode(rawValue: $0) }
        
        let dirValue = queryItems.first(where: { $0.name == "dir" })?.value
        let sortDirection = dirValue.flatMap { SortDirection(rawValue: $0) }
        
        let result = try await client.searchCards(
            query: query,
            unique: unique,
            order: order,
            sortDirection: sortDirection,
            page: page
        )
        
        return SearchResult(
            cards: result.data,
            totalCount: result.totalCards ?? result.data.count,
            nextPageURL: result.nextPage,
            warnings: result.warnings ?? []
        )
    }
    
    func fetchCard(byId id: String) async throws -> Card {
        return try await client.getCard(identifier: .scryfallID(id))
    }
    
    static func buildSearchURL(filters: [SearchFilter], config: SearchConfiguration, forAPI: Bool) -> URL? {
        let queryString = filters.map { $0.queryStringWithEditingRange.0 }.joined(separator: " ")
        
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

// MARK: - Search Result

struct SearchResult {
    let cards: [Card]
    let totalCount: Int
    let nextPageURL: String?
    let warnings: [String]
}
