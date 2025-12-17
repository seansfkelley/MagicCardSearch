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
    
    init(expiration: Expiration, label: String = "MemoryCache") {
        self.expiration = expiration
    }
    
    // MARK: - Cache Protocol Conformance
    
    func clearAll() {
        cache.removeAllObjects()
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
