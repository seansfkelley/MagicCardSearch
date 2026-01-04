import Foundation
import ScryfallKit

/// Utility functions for fetching all pages from Scryfall API
enum ScryfallPagination {
    /// Fetches all pages from an initial ObjectList request and returns a flat array
    /// - Parameter initialRequest: A closure that performs the initial ScryfallClient request
    /// - Returns: An array containing all items from all pages
    static func fetchAllPages<T: Codable>(
        initialRequest: () async throws -> ObjectList<T>
    ) async throws -> [T] {
        var allItems: [T] = []
        var currentList = try await initialRequest()
        allItems.append(contentsOf: currentList.data)
        
        while let nextPageURL = currentList.nextPage {
            currentList = try await fetchObjectList(from: nextPageURL)
            allItems.append(contentsOf: currentList.data)
        }
        
        return allItems
    }
    
    /// Fetches a Scryfall ObjectList from a URL using URLSession and ScryfallKit's ObjectList type
    private static func fetchObjectList<T: Codable>(from urlString: String) async throws -> ObjectList<T> {
        guard let url = URL(string: urlString) else {
            throw NSError(
                domain: "ScryfallPagination",
                code: 400,
                userInfo: [NSLocalizedDescriptionKey: "Invalid URL: \(urlString)"]
            )
        }
        
        var request = URLRequest(url: url)
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        
        let (data, response) = try await URLSession.shared.data(for: request)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw NSError(
                domain: "ScryfallPagination",
                code: 500,
                userInfo: [NSLocalizedDescriptionKey: "Invalid response type"]
            )
        }
        
        guard httpResponse.statusCode == 200 else {
            throw NSError(
                domain: "ScryfallPagination",
                code: httpResponse.statusCode,
                userInfo: [NSLocalizedDescriptionKey: "HTTP error: \(httpResponse.statusCode)"]
            )
        }
        
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        decoder.dateDecodingStrategy = .iso8601
        
        return try decoder.decode(ObjectList<T>.self, from: data)
    }
}
