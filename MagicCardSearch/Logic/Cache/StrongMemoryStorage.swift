import Foundation
import Cache

/// A dictionary-backed alternative to Cache's `MemoryStorage` that maintains strong references
/// to all cached objects, preventing the system from evicting them under memory pressure.
///
/// Unlike `MemoryStorage` (which uses `NSCache`), this class **does not support costs**.
class StrongMemoryStorage<Key: Hashable, Value>: StorageAware {
    private struct Capsule {
        let object: Value
        let expiry: Expiry
    }

    private var storage = [Key: Capsule]()
    private let config: MemoryConfig

    init(config: MemoryConfig) {
        self.config = config
    }

    var allKeys: [Key] {
        Array(storage.keys)
    }

    var allObjects: [Value] {
        storage.values.map(\.object)
    }

    func setObject(_ object: Value, forKey key: Key, expiry: Expiry? = nil) {
        let capsule = Capsule(
            object: object,
            expiry: .date(expiry?.date ?? config.expiry.date)
        )
        storage[key] = capsule
        evictIfNeeded()
    }

    func removeObject(forKey key: Key) {
        storage.removeValue(forKey: key)
    }

    func removeInMemoryObject(forKey key: Key) throws {
        storage.removeValue(forKey: key)
    }

    func removeAll() {
        storage.removeAll()
    }

    func removeExpiredObjects() {
        for key in storage.keys {
            if let capsule = storage[key], capsule.expiry.isExpired {
                storage.removeValue(forKey: key)
            }
        }
    }

    func entry(forKey key: Key) throws -> Entry<Value> {
        guard let capsule = storage[key] else {
            throw StorageError.notFound
        }

        return Entry(object: capsule.object, expiry: capsule.expiry)
    }

    // MARK: - Private

    private func evictIfNeeded() {
        guard config.countLimit > 0, storage.count > config.countLimit else {
            return
        }

        removeExpiredObjects()

        while storage.count > config.countLimit {
            if let key = storage.keys.first {
                storage.removeValue(forKey: key)
            }
        }
    }
}
