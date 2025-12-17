//
//  DiskCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import Foundation

/// A generic cache that stores Codable values both in memory and on disk.
/// Based on implementation from Swift by Sundell: https://www.swiftbysundell.com/articles/caching-in-swift/
final class HybridCache<Key: Hashable, Value: Codable>: @unchecked Sendable {
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
    private let diskCacheURL: URL
    private let expirationInterval: TimeInterval
    private let fileManager: FileManager
    private let queue = DispatchQueue(label: "com.magicardsearch.diskcache", attributes: .concurrent)
    
    // MARK: - Initialization
    
    /// Creates a new disk cache.
    /// - Parameters:
    ///   - name: The name of the cache directory on disk
    ///   - expirationDays: Number of days before cached items expire
    ///   - fileManager: The file manager to use for disk operations
    init(name: String, expirationDays: Int, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.expirationInterval = TimeInterval(expirationDays * 24 * 60 * 60)
        
        let cachesURL = fileManager.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        diskCacheURL = cachesURL.appendingPathComponent(name, isDirectory: true)
        
        // Create cache directory if needed
        try? fileManager.createDirectory(at: diskCacheURL, withIntermediateDirectories: true)
    }
    
    // MARK: - Public Methods
    
    /// Inserts a value for the given key.
    func insert(_ value: Value, forKey key: Key) {
        let expirationDate = Date().addingTimeInterval(expirationInterval)
        let entry = Entry(value: value, expirationDate: expirationDate)
        
        // Store in memory cache
        memoryCache.setObject(entry, forKey: WrappedKey(key))
        
        // Store on disk asynchronously
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            let fileURL = self.fileURL(for: key)
            
            do {
                let wrapper = CacheEntryWrapper(value: value, expirationDate: expirationDate)
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
        
        // Check disk cache
        return queue.sync {
            let fileURL = fileURL(for: key)
            
            guard let data = try? Data(contentsOf: fileURL),
                  let wrapper = try? JSONDecoder().decode(CacheEntryWrapper<Value>.self, from: data) else {
                return nil
            }
            
            guard Date() <= wrapper.expirationDate else {
                removeValue(forKey: key)
                return nil
            }
            
            // Restore to memory cache
            let entry = Entry(value: wrapper.value, expirationDate: wrapper.expirationDate)
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
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            let fileURL = self.fileURL(for: key)
            try? self.fileManager.removeItem(at: fileURL)
        }
    }
    
    /// Clears all cached values from both memory and disk.
    func clearAll() {
        memoryCache.removeAllObjects()
        
        queue.async(flags: .barrier) { [weak self] in
            guard let self = self else { return }
            
            do {
                let contents = try self.fileManager.contentsOfDirectory(
                    at: self.diskCacheURL,
                    includingPropertiesForKeys: nil
                )
                
                for fileURL in contents {
                    try? self.fileManager.removeItem(at: fileURL)
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
    
    private func fileURL(for key: Key) -> URL {
        let fileName = String(describing: key).addingPercentEncoding(withAllowedCharacters: .alphanumerics) ?? "cache"
        return diskCacheURL.appendingPathComponent(fileName)
    }
}

// MARK: - Supporting Types

private struct CacheEntryWrapper<T: Codable>: Codable {
    let value: T
    let expirationDate: Date
}
