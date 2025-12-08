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
    private static let webBaseURL = "https://scryfall.com/search"
    
    func search(filters: [SearchFilter], config: SearchConfiguration) async throws -> [CardResult] {
        guard let url = CardSearchService.buildSearchURL(filters: filters, config: config, forAPI: true) else {
            return []
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SearchError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SearchError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(ScryfallSearchResponse.self, from: data)
        
        return searchResponse.data
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
