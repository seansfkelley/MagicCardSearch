//
//  HybridCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import Foundation
import Logging

private let logger = Logger(label: "HybridCache")

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
/// // Use the cache with subscripts
/// cache["avatar.jpg"] = imageData
/// if let data = cache["avatar.jpg"] {
///     // Use cached data
/// }
///
/// // Or use the convenience method
/// let data = cache.get(forKey: "avatar.jpg") {
///     // Fetch the data if not cached
///     return fetchImageData()
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
    ///   - label: The label to use for logging (defaults to "HybridCache")
    init(memoryCache: MemoryCache<Key, Value>, diskCache: DiskCache<Key, Value>, label: String = "HybridCache") {
        self.memoryCache = memoryCache
        self.diskCache = diskCache
    }
    
    // MARK: - Cache Protocol Conformance
    
    /// Clears all cached values from both memory and disk.
    func clearAll() {
        memoryCache.clearAll()
        diskCache.clearAll()
    }
    
    // MARK: - Subscript
    
    subscript(key: Key) -> Value? {
        get {
            if let memoryValue = memoryCache[key] {
                logger.debug("Cache hit from memory", metadata: ["key": "\(key)"])
                return memoryValue
            }
            
            if let diskValue = diskCache[key] {
                logger.debug("Cache hit from disk, promoting to memory", metadata: ["key": "\(key)"])
                memoryCache[key] = diskValue
                return diskValue
            }
            
            logger.debug("Cache miss", metadata: ["key": "\(key)"])
            return nil
        }
        set {
            if let value = newValue {
                logger.debug("Cache set", metadata: ["key": "\(key)"])
                memoryCache[key] = value
                diskCache[key] = value
            } else {
                logger.debug("Cache remove", metadata: ["key": "\(key)"])
                memoryCache[key] = nil
                diskCache[key] = nil
            }
        }
    }
}

// MARK: - Convenience Initializers

extension HybridCache {
    /// Creates a hybrid cache with the specified name and expiration policy.
    /// This convenience initializer creates both memory and disk caches with the same expiration.
    /// - Parameters:
    ///   - name: The name to use for the disk cache directory and logger label
    ///   - expiration: The expiration policy to use for both caches
    convenience init?(name: String, expiration: Expiration) {
        guard let diskCache = DiskCache<Key, Value>(name: name, expiration: expiration) else {
            return nil
        }
        let memoryCache = MemoryCache<Key, Value>(expiration: expiration, label: "\(name).memory")
        self.init(memoryCache: memoryCache, diskCache: diskCache, label: name)
    }
    
    /// Creates a hybrid cache with the specified name and separate expiration policies.
    /// - Parameters:
    ///   - name: The name to use for the disk cache directory and logger label
    ///   - memoryExpiration: The expiration policy for the memory cache
    ///   - diskExpiration: The expiration policy for the disk cache
    convenience init?(name: String, memoryExpiration: Expiration, diskExpiration: Expiration) {
        guard let diskCache = DiskCache<Key, Value>(name: name, expiration: diskExpiration) else {
            return nil
        }
        let memoryCache = MemoryCache<Key, Value>(expiration: memoryExpiration, label: "\(name).memory")
        self.init(memoryCache: memoryCache, diskCache: diskCache, label: name)
    }
}
