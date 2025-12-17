import Foundation
import ScryfallKit
import Cache

public actor SymbologyCatalog {
    // MARK: - Singleton
    
    public static let shared = SymbologyCatalog()
    
    // MARK: - Private Properties
    
    private let scryfallClient = ScryfallClient()
    private static let cache: Storage<String, [Card.Symbol]>? = {
        let diskConfig = DiskConfig(
            name: "Symbology",
            expiry: .seconds(60 * 60 * 24 * 1),
            maxSize: 10_000_000,
        )
        let memoryConfig = MemoryConfig(
            expiry: .seconds(60 * 60 * 24),
        )
        
        return try? Storage<String, [Card.Symbol]>(
            diskConfig: diskConfig,
            memoryConfig: memoryConfig,
            fileManager: FileManager.default,
            transformer: TransformerFactory.forCodable(ofType: [Card.Symbol].self),
        )
    }()
    
    // MARK: - Initialization
    
    private init() {}
    
    // MARK: - Public Methods
    
    public func getSymbol(_ symbol: String) async throws -> Card.Symbol? {
        let symbols = try await getAllSymbols()
        return symbols.first { $0.symbol == notation }
    }
    
    @discardableResult
    public func refreshCache() async throws -> [Card.Symbol] {
        // Fetch fresh data from Scryfall
        let objectList = try await scryfallClient.getSymbology()
        let symbols = objectList.data
        
        // Create new cached list
        let symbolList = SymbolList(symbols: symbols, fetchedDate: Date())
        
        // Store in cache
        try? cache?.setObject(symbolList, forKey: Self.symbolListKey)
        
        return symbols
    }
    
    public func clearCache() async throws {
        try? cache?.removeObject(forKey: Self.symbolListKey)
        try? cache?.removeAll()
    }
}
