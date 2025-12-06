//
//  CardSearchService.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

@MainActor
class CardSearchService {
    private let baseURL = "https://api.scryfall.com/cards/search"
    
    func search(filters: [SearchFilter]) async throws -> [CardResult] {
        // Build the search query from filters
        let queryString = filters.map { $0.toScryfallString() }.joined(separator: " ")
        
        guard !queryString.isEmpty else {
            return []
        }
        
        // Construct URL with query parameters
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "q", value: queryString),
            URLQueryItem(name: "unique", value: "cards"),
            URLQueryItem(name: "order", value: "name")
        ]
        
        guard let url = components.url else {
            throw SearchError.invalidURL
        }
        
        // Make the request
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw SearchError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw SearchError.httpError(statusCode: httpResponse.statusCode)
        }
        
        // Decode the response
        let decoder = JSONDecoder()
        let searchResponse = try decoder.decode(ScryfallSearchResponse.self, from: data)
        
        return searchResponse.data
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
