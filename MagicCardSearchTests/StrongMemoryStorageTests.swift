import Foundation
import Testing
import Cache
@testable import MagicCardSearch

@Suite
struct StrongMemoryStorageTests {
    @Test func setAndRetrieveObject() throws {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        storage.setObject(42, forKey: "answer")

        let entry = try storage.object(forKey: "answer")
        #expect(entry == 42)
    }

    @Test func entryForMissingKeyThrows() {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        #expect(throws: StorageError.notFound) {
            try storage.object(forKey: "missing")
        }
    }

    @Test func removeObject() throws {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        storage.setObject(1, forKey: "a")
        storage.removeObject(forKey: "a")

        #expect(throws: StorageError.notFound) {
            try storage.object(forKey: "a")
        }
    }

    @Test func removeAll() throws {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        storage.setObject(1, forKey: "a")
        storage.setObject(2, forKey: "b")
        storage.removeAll()

        #expect(storage.allKeys.isEmpty)
        #expect(storage.allObjects.isEmpty)
    }

    @Test func allKeysAndAllObjects() {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        storage.setObject(1, forKey: "a")
        storage.setObject(2, forKey: "b")

        #expect(Set(storage.allKeys) == Set(["a", "b"]))
        #expect(Set(storage.allObjects) == Set([1, 2]))
    }

    @Test func overwriteExistingKey() throws {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        storage.setObject(1, forKey: "a")
        storage.setObject(2, forKey: "a")

        let object = try storage.object(forKey: "a")
        #expect(object == 2)
        #expect(storage.allKeys.count == 1)
    }

    @Test func expiredObjectIsRemoved() throws {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        storage.setObject(1, forKey: "a", expiry: .date(Date.distantPast))

        storage.removeExpiredObjects()

        #expect(throws: StorageError.notFound) {
            try storage.object(forKey: "a")
        }
    }

    @Test func nonExpiredObjectIsKept() throws {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        storage.setObject(1, forKey: "a", expiry: .date(Date.distantFuture))

        storage.removeExpiredObjects()

        let object = try storage.object(forKey: "a")
        #expect(object == 1)
    }

    @Test func defaultExpiryFromConfig() throws {
        let storage = StrongMemoryStorage<String, Int>(
            config: .init(expiry: .date(Date.distantPast))
        )
        storage.setObject(1, forKey: "a")

        storage.removeExpiredObjects()

        #expect(throws: StorageError.notFound) {
            try storage.object(forKey: "a")
        }
    }

    @Test func perObjectExpiryOverridesConfig() throws {
        let storage = StrongMemoryStorage<String, Int>(
            config: .init(expiry: .date(Date.distantPast))
        )
        storage.setObject(1, forKey: "a", expiry: .date(Date.distantFuture))

        storage.removeExpiredObjects()

        let object = try storage.object(forKey: "a")
        #expect(object == 1)
    }

    @Test func countLimitEvicts() {
        let storage = StrongMemoryStorage<String, Int>(config: .init(countLimit: 2))
        storage.setObject(1, forKey: "a")
        storage.setObject(2, forKey: "b")
        storage.setObject(3, forKey: "c")

        #expect(storage.allKeys.count == 2)
    }

    @Test func zeroCountLimitMeansUnlimited() {
        let storage = StrongMemoryStorage<String, Int>(config: .init(countLimit: 0))
        for i in 0..<100 {
            storage.setObject(i, forKey: "\(i)")
        }

        #expect(storage.allKeys.count == 100)
    }

    @Test func countLimitEvictsExpiredFirst() {
        let storage = StrongMemoryStorage<String, Int>(config: .init(countLimit: 2))
        storage.setObject(1, forKey: "a", expiry: .date(Date.distantPast))
        storage.setObject(2, forKey: "b", expiry: .date(Date.distantFuture))
        // This insert triggers eviction; the expired "a" should be removed first.
        storage.setObject(3, forKey: "c", expiry: .date(Date.distantFuture))

        #expect(storage.allKeys.count == 2)
        #expect(!storage.objectExists(forKey: "a"))
        #expect(storage.objectExists(forKey: "b"))
        #expect(storage.objectExists(forKey: "c"))
    }

    @Test func removeInMemoryObject() throws {
        let storage = StrongMemoryStorage<String, Int>(config: .init())
        storage.setObject(1, forKey: "a")
        try storage.removeInMemoryObject(forKey: "a")

        #expect(throws: StorageError.notFound) {
            try storage.object(forKey: "a")
        }
    }
}
