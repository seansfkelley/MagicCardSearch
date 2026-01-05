import Foundation

final class MemoryCache<Key: Hashable & Sendable, Value: Sendable>: @unchecked Sendable {
    private final class KeyWrapper: NSObject {
        let key: Key
        init(_ key: Key) { self.key = key }
        override var hash: Int { key.hashValue }
        override func isEqual(_ object: Any?) -> Bool {
            guard let other = object as? KeyWrapper else { return false }
            return key == other.key
        }
    }
    
    private final class ValueWrapper {
        let value: Value
        init(_ value: Value) { self.value = value }
    }
    
    private let cache = NSCache<KeyWrapper, ValueWrapper>()
    
    subscript(key: Key) -> Value? {
        get {
            cache.object(forKey: KeyWrapper(key))?.value
        }
        set {
            if let value = newValue {
                cache.setObject(ValueWrapper(value), forKey: KeyWrapper(key))
            } else {
                cache.removeObject(forKey: KeyWrapper(key))
            }
        }
    }
    
    func get(_ key: Key, fetch: @Sendable () throws -> Value) rethrows -> Value {
        if let cached = self[key] {
            return cached
        }
        let value = try fetch()
        self[key] = value
        return value
    }
    
    func get(_ key: Key, fetch: @Sendable () async throws -> Value) async rethrows -> Value {
        if let cached = self[key] {
            return cached
        }
        let value = try await fetch()
        self[key] = value
        return value
    }
}
