//
//  CardSearchService.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

@MainActor
class CardSearchService {
    private static let apiBaseURL = "https://api.scryfall.com/cards/search"
    private static let cardByIdURL = "https://api.scryfall.com/cards"
    private static let webBaseURL = "https://scryfall.com/search"
    
    func search(filters: [SearchFilter], config: SearchConfiguration) async throws -> SearchResult {
        guard let url = CardSearchService.buildSearchURL(filters: filters, config: config, forAPI: true) else {
            return SearchResult(cards: [], totalCount: 0, nextPageURL: nil, warnings: [])
        }
        
        return try await fetchPage(from: url)
    }
    
    func fetchNextPage(from urlString: String) async throws -> SearchResult {
        guard let url = URL(string: urlString) else {
            throw SearchError.invalidURL
        }
        
        return try await fetchPage(from: url)
    }
    
    private func fetchPage(from url: URL) async throws -> SearchResult {
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SearchError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SearchError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(ScryfallSearchResponse.self, from: data)
        
        return SearchResult(
            cards: searchResponse.data,
            totalCount: searchResponse.totalCards ?? searchResponse.data.count,
            nextPageURL: searchResponse.nextPage,
            warnings: searchResponse.warnings ?? []
        )
    }
    
    func fetchCard(byId id: String) async throws -> CardResult {
        let urlString = "\(CardSearchService.cardByIdURL)/\(id)"
        guard let url = URL(string: urlString) else {
            throw SearchError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SearchError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SearchError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let card = try decoder.decode(CardResult.self, from: data)
        
        return card
    }
    
    static func buildSearchURL(filters: [SearchFilter], config: SearchConfiguration, forAPI: Bool) -> URL? {
        let queryString = filters.map { $0.queryStringWithEditingRange.0 }.joined(separator: " ")
        
        guard !queryString.isEmpty else {
            return nil
        }
        
        let baseURL = forAPI ? apiBaseURL : webBaseURL
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: queryString),
            URLQueryItem(name: "unique", value: config.uniqueMode.apiValue),
            URLQueryItem(name: "order", value: config.sortField.apiValue),
            URLQueryItem(name: "dir", value: config.sortOrder.apiValue)
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
    let cards: [CardResult]
    let totalCount: Int
    let nextPageURL: String?
    let warnings: [String]
}
