import Foundation
import ScryfallKit

/// A caching service for MTG sets that provides fast, case-insensitive lookup by set code.
///
/// This service uses `CachedDataManager` internally to cache sets from Scryfall with a 1-day
/// expiration period. It provides a simple interface for retrieving sets by their code.
///
/// Example usage:
/// ```swift
/// // Get a set by code
/// if let set = try await MTGSetCache.shared.getSet(byCode: "MH3") {
///     print("Found: \(set.name)")
/// }
/// ```
public actor MTGSetCache {
    // MARK: - Singleton
    
    /// Shared singleton instance for accessing cached MTG sets
    public static let shared = MTGSetCache()
    
    // MARK: - Private Properties
    
    private let cacheManager: CachedDataManager<MTGSet>
    private let scryfallClient: ScryfallClient
    
    // MARK: - Initialization
    
    private init() {
        self.scryfallClient = ScryfallClient()
        
        self.cacheManager = CachedDataManager<MTGSet>(
            expirationDays: 1,
            fileBasename: "mtg_sets",
        ) { [scryfallClient] in
            let objectList = try await scryfallClient.getSets()
            return objectList.data
        }
    }
    
    // MARK: - Public Methods
    
    /// Retrieves a set by its code (case-insensitive).
    ///
    /// This method fetches all cached sets and performs a case-insensitive search
    /// for the requested set code. The cache is automatically refreshed if expired
    /// or missing.
    ///
    /// - Parameter code: The set code to search for (e.g., "MH3", "m3c", "BRO")
    /// - Returns: The matching `MTGSet` if found, or `nil` if no set matches the code
    /// - Throws: Any error from fetching sets from Scryfall if the cache needs to be refreshed
    public func getSet(byCode code: String) async throws -> MTGSet? {
        let sets = try await cacheManager.getData()
        let normalizedCode = code.lowercased()
        return sets.first { $0.code.lowercased() == normalizedCode }
    }
    
    /// Retrieves all cached sets.
    ///
    /// - Returns: Array of all cached `MTGSet` objects
    /// - Throws: Any error from fetching sets from Scryfall if the cache needs to be refreshed
    public func getAllSets() async throws -> [MTGSet] {
        return try await cacheManager.getData()
    }
    
    /// Forces a refresh of the set cache from Scryfall.
    ///
    /// Use this method when you want to ensure you have the latest set data,
    /// regardless of the cache expiration status.
    ///
    /// - Returns: Array of freshly fetched `MTGSet` objects
    /// - Throws: Any error from fetching sets from Scryfall
    @discardableResult
    public func refreshCache() async throws -> [MTGSet] {
        return try await cacheManager.refreshData()
    }
    
    /// Clears the set cache from memory and disk.
    ///
    /// - Throws: Any file system errors encountered during cache deletion
    public func clearCache() async throws {
        try await cacheManager.clearCache()
    }
}
