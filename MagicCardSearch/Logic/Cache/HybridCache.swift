//
//  DiskCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import Foundation

/// A generic cache that stores Codable values both in memory and on disk.
/// This cache composes a MemoryCache and DiskCache, delegating to each as appropriate.
/// Based on implementation from Swift by Sundell: https://www.swiftbysundell.com/articles/caching-in-swift/
///
/// Example usage:
/// ```swift
/// // Option 1: Provide your own cache instances for maximum control
/// let memoryCache = MemoryCache<String, Data>(expiration: .interval(60 * 5)) // 5 minutes
/// let diskCache = DiskCache<String, Data>(name: "images", expiration: .interval(60 * 60 * 24))! // 1 day
/// let hybridCache = HybridCache(memoryCache: memoryCache, diskCache: diskCache)
///
/// // Option 2: Use convenience initializers with the same expiration for both
/// let cache = HybridCache<String, Data>(
///     name: "images",
///     expiration: .interval(60 * 60 * 24)  // 1 day
/// )
///
/// // Option 3: Use separate expirations for memory and disk
/// let cache2 = HybridCache<String, Data>(
///     name: "images",
///     memoryExpiration: .interval(60 * 5),    // 5 minutes in memory
///     diskExpiration: .interval(60 * 60 * 24)  // 1 day on disk
/// )
///
/// // Option 4: Use a never-expiring cache
/// let permanentCache = HybridCache<String, Data>(
///     name: "permanent",
///     expiration: .never
/// )
///
/// // Use the cache
/// cache.insert(imageData, forKey: "avatar.jpg")
/// if let data = cache.value(forKey: "avatar.jpg") {
///     // Use cached data
/// }
/// ```
final class HybridCache<Key: Hashable & Sendable, Value: Codable & Sendable>: Cache, @unchecked Sendable {
    // MARK: - Private Properties
    
    private let memoryCache: MemoryCache<Key, Value>
    private let diskCache: DiskCache<Key, Value>
    
    // MARK: - Initialization
    
    /// Creates a hybrid cache with the provided memory and disk caches.
    /// - Parameters:
    ///   - memoryCache: The memory cache to use for fast access
    ///   - diskCache: The disk cache to use for persistent storage
    init(memoryCache: MemoryCache<Key, Value>, diskCache: DiskCache<Key, Value>) {
        self.memoryCache = memoryCache
        self.diskCache = diskCache
    }
    
    // MARK: - Cache Protocol Conformance
    
    /// Inserts a value for the given key in both memory and disk caches.
    func insert(_ value: Value, forKey key: Key) {
        // Store in both caches
        memoryCache.insert(value, forKey: key)
        diskCache.insert(value, forKey: key)
    }
    
    /// Retrieves the value for the given key, checking memory first, then disk.
    /// If found on disk but not in memory, the value is restored to the memory cache.
    func value(forKey key: Key) -> Value? {
        // Check memory cache first (fast path)
        if let memoryValue = memoryCache.value(forKey: key) {
            return memoryValue
        }
        
        // Check disk cache (slower path)
        if let diskValue = diskCache.value(forKey: key) {
            // Restore to memory cache for future fast access
            memoryCache.insert(diskValue, forKey: key)
            return diskValue
        }
        
        return nil
    }
    
    /// Removes the value for the given key from both memory and disk caches.
    func removeValue(forKey key: Key) {
        memoryCache.removeValue(forKey: key)
        diskCache.removeValue(forKey: key)
    }
    
    /// Clears all cached values from both memory and disk.
    func clearAll() {
        memoryCache.clearAll()
        diskCache.clearAll()
    }
    
    // MARK: - Subscript
    
    subscript(key: Key) -> Value? {
        get {
            return value(forKey: key)
        }
        set {
            if let value = newValue {
                insert(value, forKey: key)
            } else {
                removeValue(forKey: key)
            }
        }
    }
}

// MARK: - Convenience Initializers

extension HybridCache {
    /// Creates a hybrid cache with the specified name and expiration policy.
    /// This convenience initializer creates both memory and disk caches with the same expiration.
    /// - Parameters:
    ///   - name: The name to use for the disk cache directory
    ///   - expiration: The expiration policy to use for both caches
    convenience init?(name: String, expiration: Expiration) {
        guard let diskCache = DiskCache<Key, Value>(name: name, expiration: expiration) else {
            return nil
        }
        let memoryCache = MemoryCache<Key, Value>(expiration: expiration)
        self.init(memoryCache: memoryCache, diskCache: diskCache)
    }
    
    /// Creates a hybrid cache with the specified name and separate expiration policies.
    /// - Parameters:
    ///   - name: The name to use for the disk cache directory
    ///   - memoryExpiration: The expiration policy for the memory cache
    ///   - diskExpiration: The expiration policy for the disk cache
    convenience init?(name: String, memoryExpiration: Expiration, diskExpiration: Expiration) {
        guard let diskCache = DiskCache<Key, Value>(name: name, expiration: diskExpiration) else {
            return nil
        }
        let memoryCache = MemoryCache<Key, Value>(expiration: memoryExpiration)
        self.init(memoryCache: memoryCache, diskCache: diskCache)
    }
}


