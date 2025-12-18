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

/// A protocol defining a readonly caching interface for retrieving values.
/// - Note: This protocol is constrained to classes (reference types) to allow non-mutating
///         methods to interact with the cache's internal state, which is essential for actor isolation.
protocol ReadonlyCache<Key, Value>: AnyObject, Sendable {
    associatedtype Key: Hashable & Sendable
    associatedtype Value: Sendable
    
    /// Subscript access to cached values (readonly).
    /// - Parameter key: The key to retrieve the value
    /// - Returns: The cached value, or nil if not found or expired
    subscript(key: Key) -> Value? { get }
}

/// A protocol defining the core caching interface for storing and retrieving values.
/// - Note: This protocol is constrained to classes (reference types) to allow non-mutating
///         methods to modify the cache's internal state, which is essential for actor isolation.
protocol Cache<Key, Value>: ReadonlyCache {
    /// Clears all cached values.
    func clearAll()
    
    /// Subscript access to cached values.
    /// - Parameter key: The key to store or retrieve the value
    /// - Returns: The cached value, or nil if not found or expired
    /// - Note: Setting to nil removes the value for the given key
    subscript(key: Key) -> Value? { get set }
    
    /// Retrieves the value for the given key, or executes the provided closure if not found.
    /// The result of the closure is automatically cached.
    ///
    /// This method ensures that only one fetch operation is in progress for a given key at a time.
    /// If multiple concurrent requests are made for the same key, they will all wait for the
    /// single in-flight request to complete.
    ///
    /// - Parameters:
    ///   - key: The key to look up
    ///   - fetchValue: A closure that returns a value if the key is not found in cache
    /// - Returns: The cached value or the result of the closure
    func get(forKey key: Key, orFetch fetchValue: @escaping @Sendable () throws -> Value) throws -> Value
    
    /// Async version: Retrieves the value for the given key, or executes the provided async closure if not found.
    /// The result of the closure is automatically cached.
    ///
    /// This method ensures that only one fetch operation is in progress for a given key at a time.
    /// If multiple concurrent requests are made for the same key, they will all wait for the
    /// single in-flight request to complete.
    ///
    /// - Parameters:
    ///   - key: The key to look up
    ///   - fetchValue: An async closure that returns a value if the key is not found in cache
    /// - Returns: The cached value or the result of the closure
    func get(forKey key: Key, orFetch fetchValue: @escaping @Sendable () async throws -> Value) async throws -> Value
}
