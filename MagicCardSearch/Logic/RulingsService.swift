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
    
    // NSCache to hold rulings keyed by oracle ID
    private let cache: NSCache<NSString, RulingsWrapper> = {
        let cache = NSCache<NSString, RulingsWrapper>()
        cache.countLimit = 200 // Cache up to 200 different cards' rulings
        return cache
    }()
    
    private init() {
        self.client = ScryfallClient(networkLogLevel: .minimal)
    }
    
    /// Fetch rulings for a card by oracle ID
    func fetchRulings(oracleId: String) async throws -> [Card.Ruling] {
        let cacheKey = oracleId as NSString
        
        // Check cache first
        if let cached = cache.object(forKey: cacheKey) {
            return cached.rulings
        }
        
        // Fetch rulings from API - we need to use the card ID from the rulings URI
        // Since we're transitioning to oracle ID-based caching, we'll need the URI for now
        throw RulingsError.oracleIdOnly
    }
    
    /// Fetch rulings from a rulings URI, cache by oracle ID if available
    func fetchRulings(from urlString: String, oracleId: String? = nil) async throws -> [Card.Ruling] {
        // Check cache first if we have an oracle ID
        if let oracleId = oracleId {
            let cacheKey = oracleId as NSString
            if let cached = cache.object(forKey: cacheKey) {
                return cached.rulings
            }
        }
        
        // Extract card ID from URL
        // Example: https://api.scryfall.com/cards/{id}/rulings
        guard let url = URL(string: urlString),
              let pathComponents = URLComponents(url: url, resolvingAgainstBaseURL: false)?.path.components(separatedBy: "/"),
              let idIndex = pathComponents.firstIndex(of: "cards"),
              idIndex + 1 < pathComponents.count else {
            throw RulingsError.invalidURL
        }
        
        let cardId = pathComponents[idIndex + 1]
        let rulings = try await client.getRulings(.scryfallID(id: cardId))
        
        // Cache the result by oracle ID if available
        if let oracleId = oracleId {
            let cacheKey = oracleId as NSString
            cache.setObject(RulingsWrapper(rulings: rulings.data), forKey: cacheKey)
        }
        
        return rulings.data
    }
}

// Wrapper class to make [Card.Ruling] work with NSCache (which requires reference types)
private class RulingsWrapper {
    let rulings: [Card.Ruling]
    
    init(rulings: [Card.Ruling]) {
        self.rulings = rulings
    }
}

// MARK: - Rulings Errors

enum RulingsError: LocalizedError {
    case invalidURL
    case invalidResponse
    case httpError(statusCode: Int)
    case oracleIdOnly
    
    var errorDescription: String? {
        switch self {
        case .invalidURL:
            return "Invalid rulings URL"
        case .invalidResponse:
            return "Invalid response from server"
        case .httpError(let statusCode):
            return "Server error: \(statusCode)"
        case .oracleIdOnly:
            return "This method requires a rulings URI"
        }
    }
}
