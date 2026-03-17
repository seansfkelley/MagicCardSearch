import Foundation
import ScryfallKit
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "CardSearchService")

@MainActor
class CardSearchService {
    private static let webBaseURL = "https://scryfall.com/search"
    
    private let client: ScryfallClient
    
    init() {
        self.client = ScryfallClient(logger: logger)
    }
    
    func fetchCard(byScryfallId id: UUID) async throws -> Card {
        return try await client.getCard(identifier: .scryfallID(id: id.uuidString))
    }
    
    func fetchCard(byOracleId id: UUID) async throws -> Card? {
        let query = "oracleId:\(id.uuidString)"
        let results = try await client.searchCards(query: query, page: 1)
        return results.data.first
    }
    
    func fetchCard(byIllustrationId id: UUID) async throws -> Card? {
        let query = "illustrationId:\(id.uuidString)"
        let results = try await client.searchCards(query: query, page: 1)
        return results.data.first
    }
    
    func fetchCard(byPrintingId id: UUID) async throws -> Card? {
        let query = "printingId:\(id.uuidString)"
        let results = try await client.searchCards(query: query, page: 1)
        return results.data.first
    }

    static func buildSearchURL(filters: [FilterQuery<FilterTerm>], config: SearchConfiguration, forAPI: Bool) -> URL? {
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
