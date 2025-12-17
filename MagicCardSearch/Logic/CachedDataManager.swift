import Foundation

/// A generic caching system that persists data to disk with expiration support.
///
/// This class manages a list of items of any `Codable` type, storing them to disk
/// along with a timestamp. When the cache expires or is missing, it automatically
/// fetches fresh data using the provided closure.
///
/// Example usage:
/// ```swift
/// let manager = CachedDataManager<MyModel>(
///     expirationDays: 7,
///     fileBasename: "mydata",
///     fetchData: {
///         // Fetch from network or other source
///         return try await fetchMyModels()
///     }
/// )
///
/// let items = try await manager.getData()
/// ```
actor CachedDataManager<T: Codable> {
    // MARK: - Properties
    
    private let expirationDays: Int
    private let fileBasename: String
    private let fetchData: () async throws -> [T]
    
    private var cachedData: CachedList<T>?
    
    // MARK: - Nested Types
    
    /// Container for the cached data and its timestamp
    private struct CachedList<Item: Codable>: Codable {
        let items: [Item]
        let lastFetchedDate: Date
        
        var isExpired: Bool {
            return isExpired(expirationDays: 0)
        }
        
        func isExpired(expirationDays: Int) -> Bool {
            let calendar = Calendar.current
            guard let expirationDate = calendar.date(byAdding: .day, value: expirationDays, to: lastFetchedDate) else {
                return true
            }
            return Date() > expirationDate
        }
    }
    
    // MARK: - Initialization
    
    /// Creates a new cached data manager.
    ///
    /// - Parameters:
    ///   - expirationDays: Number of days before cached data expires
    ///   - fileBasename: Base name for the cache file (without extension)
    ///   - fetchData: Async closure that fetches fresh data when needed
    init(
        expirationDays: Int,
        fileBasename: String,
        fetchData: @escaping () async throws -> [T]
    ) {
        self.expirationDays = expirationDays
        self.fileBasename = fileBasename
        self.fetchData = fetchData
    }
    
    // MARK: - Public Methods
    
    /// Returns the cached data, loading from disk or fetching fresh data as needed.
    ///
    /// This method will:
    /// 1. Try to load from memory cache if available and not expired
    /// 2. Try to load from disk if memory cache is unavailable
    /// 3. Fetch fresh data if disk cache is missing, corrupted, or expired
    ///
    /// - Returns: Array of cached items
    /// - Throws: Any error from the fetch closure if data needs to be reloaded
    func getData() async throws -> [T] {
        // Check memory cache first
        if let cached = cachedData, !cached.isExpired(expirationDays: expirationDays) {
            return cached.items
        }
        
        // Try loading from disk
        if let loaded = try? loadFromDisk(), !loaded.isExpired(expirationDays: expirationDays) {
            cachedData = loaded
            return loaded.items
        }
        
        // Need to fetch fresh data
        return try await refreshData()
    }
    
    /// Forces a refresh of the data from the fetch closure.
    ///
    /// - Returns: Array of newly fetched items
    /// - Throws: Any error from the fetch closure
    @discardableResult
    func refreshData() async throws -> [T] {
        let items = try await fetchData()
        let cached = CachedList(items: items, lastFetchedDate: Date())
        
        cachedData = cached
        try saveToDisk(cached)
        
        return items
    }
    
    /// Clears the cache from memory and disk.
    func clearCache() throws {
        cachedData = nil
        try? FileManager.default.removeItem(at: fileURL())
    }
    
    // MARK: - Private Methods
    
    private func fileURL() throws -> URL {
        let directory = try FileManager.default.url(
            for: .cachesDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        return directory.appendingPathComponent("\(fileBasename).json")
    }
    
    private func loadFromDisk() throws -> CachedList<T> {
        let url = try fileURL()
        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(CachedList<T>.self, from: data)
    }
    
    private func saveToDisk(_ cached: CachedList<T>) throws {
        let url = try fileURL()
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(cached)
        try data.write(to: url, options: .atomic)
    }
}
