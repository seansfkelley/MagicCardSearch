import Foundation
import ScryfallKit

@MainActor
class CardSearchService {
    private static let webBaseURL = "https://scryfall.com/search"
    
    private let client: ScryfallClient
    
    init() {
        self.client = ScryfallClient(networkLogLevel: .minimal)
    }
    
    func fetchCard(byId id: UUID) async throws -> Card {
        return try await client.getCard(identifier: .scryfallID(id: id.uuidString))
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
