//
//  Cache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import Foundation

enum Expiration: Sendable {
    case never
    case interval(TimeInterval)
    case date(Date)
    
    /// Converts the expiration to an optional expiration date based on the current time
    func expirationDate(from baseDate: Date = Date()) -> Date? {
        switch self {
        case .never:
            return nil
        case .interval(let timeInterval):
            return baseDate.addingTimeInterval(timeInterval)
        case .date(let date):
            return date
        }
    }
}

/// A protocol defining the core caching interface for storing and retrieving values.
protocol Cache<Key, Value>: Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable
    
    /// Inserts a value for the given key.
    /// - Parameters:
    ///   - value: The value to store
    ///   - key: The key to associate with the value
    func insert(_ value: Value, forKey key: Key)
    
    /// Retrieves the value for the given key, if it exists and hasn't expired.
    /// - Parameter key: The key to look up
    /// - Returns: The cached value, or nil if not found or expired
    func value(forKey key: Key) -> Value?
    
    /// Removes the value for the given key.
    /// - Parameter key: The key whose value should be removed
    func removeValue(forKey key: Key)
    
    /// Clears all cached values.
    func clearAll()
    
    /// Subscript access to cached values.
    subscript(key: Key) -> Value? { get set }
}

/// Extension providing convenience methods for caches.
extension Cache {
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
}
