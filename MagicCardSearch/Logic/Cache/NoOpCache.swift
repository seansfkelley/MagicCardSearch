//
//  NoOpCache.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-17.
//

import Foundation

/// A no-op cache implementation that never stores any values.
/// All insert operations are ignored, and all lookups return nil.
/// Useful for testing, debugging, or disabling caching in certain configurations.
final class NoOpCache<Key: Hashable & Sendable, Value: Sendable>: Cache, Sendable {
    init() {}
    
    // MARK: - Cache Protocol Conformance
    
    func clearAll() {}
    
    func get(forKey key: Key, orFetch fetchValue: @Sendable () throws -> Value) throws -> Value {
        try fetchValue()
    }

    func get(forKey key: Key, orFetch fetchValue: @Sendable () async throws -> Value) async throws -> Value {
        try await fetchValue()
    }
    
    subscript(key: Key) -> Value? {
        get { nil }
        // swiftlint:disable:next unused_setter_value
        set { }
    }
}
