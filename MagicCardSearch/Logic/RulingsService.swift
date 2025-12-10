//
//  RulingsService.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import Foundation
import ScryfallKit

@MainActor
class RulingsService {
    static let shared = RulingsService()
    
    private let client: ScryfallClient
    private var cache: [String: [Card.Ruling]] = [:]
    
    private init() {
        self.client = ScryfallClient(networkLogLevel: .minimal)
    }
    
    /// Fetch rulings for a card by ID
    func fetchRulings(cardId: String) async throws -> [Card.Ruling] {
        // Check cache first
        if let cached = cache[cardId] {
            return cached
        }
        
        let rulings = try await client.getRulings(identifier: .scryfallID(id: cardId))
        
        // Cache the result
        cache[cardId] = rulings
        
        return rulings
    }
    
    /// Legacy method that accepts a URL string (extracts card ID from it)
    func fetchRulings(from urlString: String) async throws -> [Card.Ruling] {
        // Extract card ID from URL
        // Example: https://api.scryfall.com/cards/{id}/rulings
        guard let url = URL(string: urlString),
              let pathComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path.components(separatedBy: "/"),
              let idIndex = pathComponents.firstIndex(of: "cards"),
              idIndex + 1 < pathComponents.count else {
            throw RulingsError.invalidURL
        }
        
        let cardId = pathComponents[idIndex + 1]
        return try await fetchRulings(cardId: cardId)
    }
}

// MARK: - Rulings Errors

enum RulingsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid rulings URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "Server error: \(statusCode)"
        }
    }
}
