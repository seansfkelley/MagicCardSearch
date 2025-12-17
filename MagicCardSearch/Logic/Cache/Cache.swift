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
    
    /// Clears all cached values.
    func clearAll()
    
    /// Subscript access to cached values.
    /// - Parameter key: The key to store or retrieve the value
    /// - Returns: The cached value, or nil if not found or expired
    /// - Note: Setting to nil removes the value for the given key
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
        if let cachedValue = self[key] {
            return cachedValue
        }
        
        let fetchedValue = try fetchValue()
        self[key] = fetchedValue
        return fetchedValue
    }
    
    /// Async version: Retrieves the value for the given key, or executes the provided async closure if not found.
    /// The result of the closure is automatically cached.
    /// - Parameters:
    ///   - key: The key to look up
    ///   - fetchValue: An async closure that returns a value if the key is not found in cache
    /// - Returns: The cached value or the result of the closure
    func get(forKey key: Key, orFetch fetchValue: @Sendable () async throws -> Value) async rethrows -> Value {
        if let cachedValue = self[key] {
            return cachedValue
        }
        
        let fetchedValue = try await fetchValue()
        self[key] = fetchedValue
        return fetchedValue
    }
}
