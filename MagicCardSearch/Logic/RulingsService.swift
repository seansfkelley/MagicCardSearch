//
//  RulingsService.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-09.
//

import Foundation

@MainActor
class RulingsService {
    static let shared = RulingsService()
    
    private var cache: [String: [Ruling]] = [:]
    
    private init() {}
    
    func fetchRulings(from urlString: String) async throws -> [Ruling] {
        // Check cache first
        if let cached = cache[urlString] {
            return cached
        }
        
        guard let url = URL(string: urlString) else {
            throw RulingsError.invalidURL
        }
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RulingsError.invalidResponse
        }
        
        guard httpResponse.statusCode == 200 else {
            throw RulingsError.httpError(statusCode: httpResponse.statusCode)
        }
        
        let decoder = JSONDecoder()
        let rulingsResponse = try decoder.decode(ScryfallRulingsResponse.self, from: data)
        
        // Cache the result
        cache[urlString] = rulingsResponse.data
        
        return rulingsResponse.data
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
