//
//  CardSearchService.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-05.
//

import Foundation

/// Service for fetching Magic card search results
@MainActor
class CardSearchService {
    
    /// Performs a search with the given filters
    /// - Parameter filters: Array of search filters to apply
    /// - Returns: Array of card results
    func search(filters: [SearchFilter]) async throws -> [CardResult] {
        // Stub implementation: return random number of stub results
        let resultCount = Int.random(in: 3...15)
        
        // Simulate network delay
        try await Task.sleep(for: .milliseconds(500))
        
        return (0..<resultCount).map { index in
            CardResult(
                id: UUID().uuidString,
                name: "Card \(index + 1)",
                imageUrl: nil
            )
        }
    }
}
