//
//  DiskCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import Foundation

/// A generic cache that stores Codable values both in memory and on disk.
/// Based on implementation from Swift by Sundell: https://www.swiftbysundell.com/articles/caching-in-swift/
final class HybridCache<Key: Hashable & Sendable, Value: Codable & Sendable>: @unchecked Sendable {
    // MARK: - Public Types
    
    enum CacheMode {
        case hybrid
        case memoryOnly
    }
    
    // MARK: - Private Types
    
    private final class WrappedKey: NSObject {
        let key: Key
        
        init(_ key: Key) {
            self.key = key
        }
        
        override var hash: Int {
            return key.hashValue
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? WrappedKey else {
                return false
            }
            return key == other.key
        }
    }
    
    private final class Entry {
        let value: Value
        let expirationDate: Date
        
        init(value: Value, expirationDate: Date) {
            self.value = value
            self.expirationDate = expirationDate
        }
        
        var isExpired: Bool {
            return Date() > expirationDate
        }
    }
    
    // MARK: - Private Properties
    
    private let memoryCache = NSCache<WrappedKey, Entry>()
    private let diskCacheURL: URL?
    private let memoryExpirationInterval: TimeInterval
    private let diskExpirationInterval: TimeInterval
    private let cacheMode: CacheMode
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.magicardsearch.diskcache", attributes: .concurrent)
    
    // MARK: - Initialization
    
    /// Creates a new cache with full configuration options.
    /// - Parameters:
    ///   - name: The name of the cache directory on disk (ignored for memory-only mode)
    ///   - cacheMode: The caching mode (.hybrid or .memoryOnly)
    ///   - memoryExpiration: Time interval before memory-cached items expire
    ///   - diskExpiration: Time interval before disk-cached items expire (ignored for memory-only mode)
    ///   - fileManager: The file manager to use for disk operations
    init(
        name: String,
        cacheMode: CacheMode = .hybrid,
        memoryExpiration: TimeInterval,
        diskExpiration: TimeInterval? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.cacheMode = cacheMode
        self.memoryExpirationInterval = memoryExpiration
        self.diskExpirationInterval = diskExpiration ?? memoryExpiration
        
        if cacheMode == .hybrid {
            let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            self.diskCacheURL = cachesURL.appendingPathComponent(name, isDirectory: true)
            
            // Create cache directory if needed
            if let diskCacheURL {
                try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
            }
        } else {
            self.diskCacheURL = nil
        }
    }
    
    /// Convenience initializer for hybrid mode with the same expiration for both memory and disk.
    /// - Parameters:
    ///   - name: The name of the cache directory on disk
    ///   - expiration: Time interval before cached items expire (applies to both memory and disk)
    ///   - fileManager: The file manager to use for disk operations
    convenience init(
        name: String,
        expiration: TimeInterval,
        fileManager: FileManager = .default
    ) {
        self.init(
            name: name,
            cacheMode: .hybrid,
            memoryExpiration: expiration,
            diskExpiration: expiration,
            fileManager: fileManager
        )
    }
    
    /// Convenience initializer for memory-only mode.
    /// - Parameters:
    ///   - expiration: Time interval before cached items expire
    convenience init(memoryOnlyWithExpiration expiration: TimeInterval) {
        self.init(
            name: "",
            cacheMode: .memoryOnly,
            memoryExpiration: expiration,
            diskExpiration: nil,
            fileManager: .default
        )
    }
    
    // MARK: - Public Methods
    
    /// Inserts a value for the given key.
    func insert(_ value: Value, forKey key: Key) {
        let memoryExpirationDate = Date().addingTimeInterval(memoryExpirationInterval)
        let entry = Entry(value: value, expirationDate: memoryExpirationDate)
        
        // Store in memory cache
        memoryCache.setObject(entry, forKey: WrappedKey(key))
        
        // Store on disk asynchronously (only in hybrid mode)
        guard cacheMode == .hybrid, let diskCacheURL else { return }
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            
            let fileURL = self.fileURL(for: key, diskCacheURL: diskCacheURL)
            
            do {
                let diskExpirationDate = Date().addingTimeInterval(self.diskExpirationInterval)
                let wrapper = CacheEntryWrapper(value: value, expirationDate: diskExpirationDate)
                let data = try JSONEncoder().encode(wrapper)
                try data.write(to: fileURL)
            } catch {
                print("Failed to write cache entry to disk: \(error)")
            }
        }
    }
    
    /// Retrieves the value for the given key, if it exists and hasn't expired.
    func value(forKey key: Key) -> Value? {
        // Check memory cache first
        if let entry = memoryCache.object(forKey: WrappedKey(key)) {
            guard !entry.isExpired else {
                removeValue(forKey: key)
                return nil
            }
            return entry.value
        }
        
        // Check disk cache (only in hybrid mode)
        guard cacheMode == .hybrid, let diskCacheURL else {
            return nil
        }
        
        return queue.sync {
            let fileURL = self.fileURL(for: key, diskCacheURL: diskCacheURL)
            
            guard let data = try? Data(contentsOf: fileURL),
                  let wrapper = try? JSONDecoder().decode(CacheEntryWrapper<Value>.self, from: data) else {
                return nil
            }
            
            guard Date() <= wrapper.expirationDate else {
                removeValue(forKey: key)
                return nil
            }
            
            // Restore to memory cache with memory expiration
            let memoryExpirationDate = Date().addingTimeInterval(memoryExpirationInterval)
            let entry = Entry(value: wrapper.value, expirationDate: memoryExpirationDate)
            memoryCache.setObject(entry, forKey: WrappedKey(key))
            
            return wrapper.value
        }
    }
    
    /// Retrieves the value for the given key, or executes the provided closure if not found.
    /// The result of the closure is automatically cached.
    /// - Parameters:
    ///   - key: The key to look up
    ///   - fetchValue: A closure that returns a value if the key is not found in cache
    /// - Returns: The cached value or the result of the closure
    func get(forKey key: Key, orFetch fetchValue: @Sendable () throws -> Value) rethrows -> Value {
        if let cachedValue = value(forKey: key) {
            return cachedValue
        }
        
        let fetchedValue = try fetchValue()
        insert(fetchedValue, forKey: key)
        return fetchedValue
    }
    
    /// Async version: Retrieves the value for the given key, or executes the provided async closure if not found.
    /// The result of the closure is automatically cached.
    /// - Parameters:
    ///   - key: The key to look up
    ///   - fetchValue: An async closure that returns a value if the key is not found in cache
    /// - Returns: The cached value or the result of the closure
    func get(forKey key: Key, orFetch fetchValue: @Sendable () async throws -> Value) async rethrows -> Value {
        if let cachedValue = value(forKey: key) {
            return cachedValue
        }
        
        let fetchedValue = try await fetchValue()
        insert(fetchedValue, forKey: key)
        return fetchedValue
    }
    
    /// Removes the value for the given key.
    func removeValue(forKey key: Key) {
        memoryCache.removeObject(forKey: WrappedKey(key))
        
        guard cacheMode == .hybrid, let diskCacheURL else { return }
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            let fileURL = self.fileURL(for: key, diskCacheURL: diskCacheURL)
            try? fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Clears all cached values from both memory and disk.
    func clearAll() {
        memoryCache.removeAllObjects()
        
        guard cacheMode == .hybrid, let diskCacheURL else { return }
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self else { return }
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: diskCacheURL,
                    includingPropertiesForKeys: nil
                )
                
                for fileURL in contents {
                    try? fileManager.removeItem(at: fileURL)
                }
            } catch {
                print("Failed to clear disk cache: \(error)")
            }
        }
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
    
    // MARK: - Private Methods
    
    private func fileURL(for key: Key, diskCacheURL: URL) -> URL {
        let fileName = String(describing: key).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "cache"
        return diskCacheURL.appendingPathComponent(fileName)
    }
}

// MARK: - Supporting Types

private struct CacheEntryWrapper<T: Codable>: Codable {
    let value: T
    let expirationDate: Date
}
