```swift
protocol Cache<K: Equatable, V> {
    func get(_ key: K) -> V?
    func get(_ key: K, through: () throws -> V) rethrows -> V
    func get(_ key: K, through: () async throws -> V) async rethrows -> V
    func get(_ key: K, expiry: Double?, through: () throws -> V) rethrows -> V
    func get(_ key: K, expiry: Double?, through: () async throws -> V) async rethrows -> V
    func put(_ key: K, _ value: V) -> Void
    func clear() -> Void
    func triggerExpiration() -> Void
}

class WeakMemoryStorage<K: Equatable, V>: Cache<K, V> {
    init(expiry: Double?)
}
class StrongMemoryStorage<K: Equatable, V>: Cache<K, V> {
    init(expiry: Double?)
}
class DiskStorage<K: Equatable, V>: Cache<K, V> {
    init(expiry: Double?, directory: URL?)
}
class TieredStorage<K: Equatable, V>: Cache<K, V> {
    init(delegates: [Cache<K, V>])
}
```
