import Foundation
import ScryfallKit

/// A caching service for MTG symbols that provides fast lookup by symbol notation.
///
/// This service uses `CachedDataManager` internally to cache symbols from Scryfall with a 1-day
/// expiration period. It provides a simple interface for retrieving symbols by their notation
/// (e.g., "{W}", "{U}", "{2}") or retrieving all symbols.
///
/// Example usage:
/// ```swift
/// // Get a specific symbol
/// if let symbol = try await MTGSymbolCache.shared.getSymbol(byNotation: "{W}") {
///     print("White mana: \(symbol.english)")
/// }
///
/// // Get all symbols
/// let allSymbols = try await MTGSymbolCache.shared.getAllSymbols()
/// ```
public actor MTGSymbolCache {
    // MARK: - Singleton
    
    /// Shared singleton instance for accessing cached MTG symbols
    public static let shared = MTGSymbolCache()
    
    // MARK: - Private Properties
    
    private let cacheManager: CachedDataManager<Card.Symbol>
    private let scryfallClient: ScryfallClient
    
    // MARK: - Initialization
    
    private init() {
        self.scryfallClient = ScryfallClient()
        
        self.cacheManager = CachedDataManager<Card.Symbol>(
            expirationDays: 1,
            fileBasename: "mtg_symbols",
        ) { [scryfallClient] in
            let objectList = try await scryfallClient.getSymbology()
            return objectList.data
        }
    }
    
    // MARK: - Public Methods
    
    /// Retrieves a symbol by its notation (e.g., "{W}", "{U}", "{2}").
    ///
    /// This method fetches all cached symbols and performs an exact search
    /// for the requested symbol notation. The cache is automatically refreshed
    /// if expired or missing.
    ///
    /// - Parameter notation: The symbol notation to search for (e.g., "{W}", "{U}", "{2/W}")
    /// - Returns: The matching `Card.Symbol` if found, or `nil` if no symbol matches
    /// - Throws: Any error from fetching symbols from Scryfall if the cache needs to be refreshed
    public func getSymbol(byNotation notation: String) async throws -> Card.Symbol? {
        let symbols = try await cacheManager.getData()
        return symbols.first { $0.symbol == notation }
    }
    
    /// Retrieves symbols by their loose variant notation.
    ///
    /// This is useful for searching symbols by their shorthand notation (e.g., "W" instead of "{W}").
    ///
    /// - Parameter looseVariant: The loose variant notation to search for (e.g., "W", "U")
    /// - Returns: Array of matching `Card.Symbol` objects (could be multiple matches)
    /// - Throws: Any error from fetching symbols from Scryfall if the cache needs to be refreshed
    public func getSymbols(byLooseVariant looseVariant: String) async throws -> [Card.Symbol] {
        let symbols = try await cacheManager.getData()
        return symbols.filter { $0.looseVariant == looseVariant }
    }
    
    /// Retrieves all cached symbols.
    ///
    /// - Returns: Array of all cached `Card.Symbol` objects
    /// - Throws: Any error from fetching symbols from Scryfall if the cache needs to be refreshed
    public func getAllSymbols() async throws -> [Card.Symbol] {
        return try await cacheManager.getData()
    }
    
    /// Retrieves only mana symbols (symbols where `representsMana` is true).
    ///
    /// - Returns: Array of mana symbols
    /// - Throws: Any error from fetching symbols from Scryfall if the cache needs to be refreshed
    public func getManaSymbols() async throws -> [Card.Symbol] {
        let symbols = try await cacheManager.getData()
        return symbols.filter { $0.representsMana }
    }
    
    /// Retrieves symbols that appear in mana costs.
    ///
    /// - Returns: Array of symbols that can appear in mana costs
    /// - Throws: Any error from fetching symbols from Scryfall if the cache needs to be refreshed
    public func getManaCostSymbols() async throws -> [Card.Symbol] {
        let symbols = try await cacheManager.getData()
        return symbols.filter { $0.appearsInManaCosts }
    }
    
    /// Forces a refresh of the symbol cache from Scryfall.
    ///
    /// Use this method when you want to ensure you have the latest symbol data,
    /// regardless of the cache expiration status.
    ///
    /// - Returns: Array of freshly fetched `Card.Symbol` objects
    /// - Throws: Any error from fetching symbols from Scryfall
    @discardableResult
    public func refreshCache() async throws -> [Card.Symbol] {
        return try await cacheManager.refreshData()
    }
    
    /// Clears the symbol cache from memory and disk.
    ///
    /// - Throws: Any file system errors encountered during cache deletion
    public func clearCache() async throws {
        try await cacheManager.clearCache()
    }
}
