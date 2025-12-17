//
//  MemoryCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//
import Foundation
import Logging

private let logger = Logger(label: "MemoryCache")

/// Configuration for memory caching behavior.
final class MemoryCache<Key: Hashable & Sendable, Value: Sendable>: Cache, @unchecked Sendable {
    let cache = NSCache<WrappedKey<Key>, Entry<Value>>()
    let expiration: Expiration
    private let inFlightTracker: InFlightRequestTracker<Key, Value>
    
    init(expiration: Expiration) {
        self.expiration = expiration
        self.inFlightTracker = InFlightRequestTracker(label: "MemoryCache")
    }
    
    // MARK: - Cache Protocol Conformance
    
    func clearAll() {
        cache.removeAllObjects()
        
        Task {
            await inFlightTracker.cancelAll()
        }
    }
    
    // MARK: - Get Methods with Request Coalescing
    
    /// Retrieves the value for the given key, or executes the provided closure if not found.
    /// Ensures only one fetch operation is in progress per key.
    func get(forKey key: Key, orFetch fetchValue: @Sendable () throws -> Value) throws -> Value {
        if let cachedValue = self[key] {
            return cachedValue
        }
        
        let fetchedValue = try fetchValue()
        self[key] = fetchedValue
        return fetchedValue
    }
    
    /// Async version: Retrieves the value for the given key, or executes the provided async closure if not found.
    /// Ensures only one fetch operation is in progress per key.
    func get(forKey key: Key, orFetch fetchValue: @escaping @Sendable () async throws -> Value) async throws -> Value {
        if let cachedValue = self[key] {
            return cachedValue
        }
        
        let value = try await inFlightTracker.getOrFetch(forKey: key, fetch: fetchValue)
        
        self[key] = value
        return value
    }
    
    subscript(key: Key) -> Value? {
        get {
            guard let entry = cache.object(forKey: WrappedKey(key)) else {
                logger.debug("Cache miss", metadata: ["key": "\(key)"])
                return nil
            }
            
            guard !entry.isExpired else {
                logger.debug("Cache expired", metadata: [
                    "key": "\(key)",
                    "expirationDate": "\(entry.expirationDate?.description ?? "nil")",
                ])
                cache.removeObject(forKey: WrappedKey(key))
                return nil
            }
            
            logger.debug("Cache hit", metadata: ["key": "\(key)"])
            return entry.value
        }
        set {
            if let value = newValue {
                logger.debug("Cache set", metadata: ["key": "\(key)"])
                let expirationDate = expiration.expirationDate()
                let entry = Entry(value: value, expirationDate: expirationDate)
                cache.setObject(entry, forKey: WrappedKey(key))
            } else {
                logger.debug("Cache remove", metadata: ["key": "\(key)"])
                cache.removeObject(forKey: WrappedKey(key))
            }
        }
    }
    
    // MARK: - Helper Types
    
    final class WrappedKey<K: Hashable>: NSObject {
        let key: K
        
        init(_ key: K) {
            self.key = key
        }
        
        override var hash: Int {
            return key.hashValue
        }
        
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? WrappedKey<K> else {
                return false
            }
            return key == other.key
        }
    }
    
    final class Entry<V> {
        let value: V
        let expirationDate: Date?
        
        init(value: V, expirationDate: Date?) {
            self.value = value
            self.expirationDate = expirationDate
        }
        
        var isExpired: Bool {
            guard let expirationDate else { return false }
            return Date() > expirationDate
        }
    }
}
