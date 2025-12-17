//
//  MemoryCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//
import Foundation

/// Configuration for memory caching behavior.
final class MemoryCache<Key: Hashable & Sendable, Value: Sendable>: Cache, @unchecked Sendable {
    let cache = NSCache<WrappedKey<Key>, Entry<Value>>()
    let expiration: Expiration
    
    init(expiration: Expiration) {
        self.expiration = expiration
    }
    
    // MARK: - Cache Protocol Conformance
    
    func insert(_ value: Value, forKey key: Key) {
        let expirationDate = expiration.expirationDate()
        let entry = Entry(value: value, expirationDate: expirationDate)
        cache.setObject(entry, forKey: WrappedKey(key))
    }
    
    func value(forKey key: Key) -> Value? {
        guard let entry = cache.object(forKey: WrappedKey(key)) else {
            return nil
        }
        
        guard !entry.isExpired else {
            removeValue(forKey: key)
            return nil
        }
        
        return entry.value
    }
    
    func removeValue(forKey key: Key) {
        cache.removeObject(forKey: WrappedKey(key))
    }
    
    func clearAll() {
        cache.removeAllObjects()
    }
    
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
