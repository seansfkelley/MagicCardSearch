# Cache Design

A replacement for the third-party `Cache` package. Motivation: testability (mockable conformances), better consumer ergonomics (cache-aside `get(_:through:)` pattern), clearer semantics and automatic eviction.

**Do not integrate into the app until the standalone implementation is complete and reviewed.**

## API

```swift
struct CacheEntry<V> {
    let value: V
    let expiryDate: Date?  // nil means never expires
}

enum Expiry {
    case never
    case date(Date)
    case seconds(Int)
    case minutes(Int)
    case hours(Int)
    case days(Int)
}

protocol Cache<K, V> {
    func get(_ key: K) -> V?
    func getWithMetadata(_ key: K) -> CacheEntry<V>?
    func get(_ key: K, expiry: Expiry?, through: () throws -> V) rethrows -> V
    func get(_ key: K, expiry: Expiry?, through: () async throws -> V) async rethrows -> V
    func put(_ key: K, _ value: V, expiry: Expiry?)
    func remove(_ key: K)
    func clear()
}

extension Cache {
    func get(_ key: K, through: () throws -> V) rethrows -> V {
        try get(key, expiry: nil, through: through)
    }

    func get(_ key: K, through: () async throws -> V) async rethrows -> V {
        try await get(key, expiry: nil, through: through)
    }

    func put(_ key: K, _ value: V) {
        put(key, value, expiry: nil)
    }
}

class WeakMemoryStorage<K: Hashable, V>: Cache<K, V> {
    init(
        expiry: Expiry = .never, 
        countLimit: Int? = nil, 
        now: @escaping () -> Date = Date.init,
        )
}
class StrongMemoryStorage<K: Hashable, V>: Cache<K, V> {
    init(
        expiry: Expiry = .never, 
        countLimit: Int? = nil, 
        gcInterval: Duration? = .seconds(300), 
        now: @escaping () -> Date = Date.init,
    )
}
class DiskStorage<K: Codable & Hashable, V>: Cache<K, V> {
    init?(
        name: String, 
        expiry: Expiry = .never, 
        encode: (V) throws -> Data, 
        decode: (Data) throws -> V, 
        countLimit: Int? = nil, 
        gcInterval: Duration? = .seconds(300), 
        now: @escaping () -> Date = Date.init,
    )
}
// Convenience init for Codable values — synthesizes encode/decode via JSONEncoder/JSONDecoder.
extension DiskStorage where V: Codable {
    convenience init?(
        name: String, expiry: 
        Expiry = .never, 
        countLimit: Int? = nil, 
        gcInterval: Duration? = .seconds(300), 
        now: @escaping () -> Date = Date.init,
    )
}
class TieredStorage<K, V>: Cache<K, V> {
    init(delegates: [any Cache<K, V>])
}
```

The `expiry` parameter on `get(_:expiry:through:)` and `put(_:_:expiry:)` overrides the storage's default expiry for that specific entry. Passing `nil` uses the storage's configured default. The convenience extensions (`put(_:_:)` and the no-expiry `get(_:through:)` variants) both pass `nil`, so they consistently inherit the storage's default — the same semantics as explicitly passing the default.

**Backing store errors are not surfaced.** A cache is never the source of truth, so a read error (disk I/O failure, decode failure, etc.) is semantically equivalent to a miss — callers cannot meaningfully handle it differently from a miss anyway. Read errors are logged internally and treated as misses; the `through` closure is called as normal. Write errors (`put`, backfill) are also logged and dropped — the caller already has the value and can use it regardless of whether it was cached. This keeps the entire protocol free of `throws`.

## Implementations

### `WeakMemoryStorage`

Backed by `NSCache<WrappedKey<K>, WrappedValue<V>>`, where `WrappedKey` is a class wrapper around `K` (required because `NSCache` keys must be `AnyObject`), and `WrappedValue` is a class holding a `value: V` and an `expiryDate: Date?` (`nil` = never expires). Expiry is checked on every access; if expired, the entry is removed from `NSCache` and `nil` is returned. When the OS evicts an entry under memory pressure, the `WrappedValue` and its value are freed immediately — no separate bookkeeping is required. `countLimit` is passed directly to `NSCache.countLimit` — it is a hint, not a hard cap; the OS may evict earlier or later.

### `StrongMemoryStorage`

Backed by a `Dictionary`. Entries are never evicted by the OS. Suitable when values must survive memory pressure (e.g. expensive-to-fetch data where a miss is costly). `countLimit` is a hint, not a hard cap. On write, if `count > countLimit * 2`, a linear scan runs: expired entries are removed first, then entries with the soonest remaining TTL until under `countLimit` (`Expiry.never` entries are last to go). This batches the O(n) cleanup cost — frequent inserts near the limit don't trigger a scan on every write. If `.never` entries must be evicted (i.e., all remaining entries have no expiry), which one is chosen is nondeterministic — this is an explicit limitation.

### `DiskStorage`

Backed by a dedicated SQLite database (via GRDB) per `DiskStorage` instance, stored in the app's Caches directory as `<name>.sqlite`. Separate databases mean concurrent writes to different caches (e.g. cards vs. searches) never contend — SQLite serializes writes per connection, so a shared database would turn independent cache operations into a bottleneck. Schema:

```sql
CREATE TABLE IF NOT EXISTS entries (
    key    BLOB    NOT NULL PRIMARY KEY,
    value  BLOB    NOT NULL,
    expiry INTEGER          -- Unix timestamp (seconds), NULL means never expires
);
```

This runs on every init and is a no-op if the table already exists. No migration system is needed — the database is purely a cache and can be deleted at any time without data loss.

Failable init — returns `nil` if the SQLite database cannot be opened or created (e.g. disk full, permissions error). Callers should handle the nil case, typically by falling back to a memory-only cache.

Two `DiskStorage` instances with the same `name` point to the same SQLite file. SQLite serializes concurrent writes across connections at the file level, so this is safe — writes from one instance are visible to the other on the next read. Prefer reusing a single instance rather than creating multiples with the same name.

**Count limit:** `countLimit` is a hint, not a hard cap. On write, if `count > countLimit * 2`, a cleanup runs: delete expired entries first, then the soonest-expiring entries until under `countLimit`. `Expiry.never` entries are last to be evicted. If `.never` entries must be evicted (i.e., all remaining entries have no expiry), which one is chosen is nondeterministic — this is an explicit limitation.

**Key serialization:** `K: Codable`, encoded to `Data` and stored as a `BLOB`. The encoding **must be stable across app versions** — if the serialized form of a key changes, prior entries for that key become unreachable (treated as misses). This holds for `String`, `UUID`, `Int`, and synthesized `Codable` structs/enums with stable field names. Types whose serialized form is non-deterministic or whose `Codable` synthesis may change between builds should not be used as `DiskStorage` keys. If a row's key fails to decode (e.g. after a key type change), the row is deleted.

**Value serialization:** Values are encoded to `Data` via the `encode` closure provided at init and stored as a blob. The convenience `Codable` init uses `JSONEncoder`/`JSONDecoder`. Encode errors are treated as write errors (logged, dropped); decode errors are treated as read errors (logged, treated as miss — the row is deleted).

### `TieredStorage`

Wraps an ordered list of `Cache` delegates (fastest first, e.g. memory before disk). Imposes no constraints on `K` or `V` — each delegate was already constructed with its own constraints.

**Read behavior:** Check delegates in order via `getWithMetadata`. On a hit in delegate N, backfill all preceding delegates (0..<N) with the found value. Backfill by calling `put(key, value, expiry: .date(foundEntry.expiryDate))` when `expiryDate` is non-nil, or `put(key, value, expiry: .never)` when nil. Using the found entry's absolute expiry date ensures a backfilled entry cannot outlive the authoritative entry — the earlier tier may hold the entry slightly longer than its own default TTL would normally allow, but it will never serve data that has expired upstream. Passing `.never` explicitly (rather than `nil`) when the upstream entry has no expiry preserves that semantic — using `nil` would instead inherit the tier's configured default, which might be shorter.

**Write behavior (`put`):** Write through to all delegates.

**Remove behavior (`remove`):** Remove from all delegates.

**Clear behavior:** Clears all delegates.

## Logging

All caches should include suitable debug/info/warn/error logging for hits and misses, as appropriate.

They should also include signpost logging via OSSignposter around closure calls, coaelescing waits, and database read/writes.

## Expiry & Garbage Collection

**On access:** All implementations check expiry on every `get` and `getWithMetadata`. If the retrieved entry is expired, it is deleted and `nil` is returned, regardless of whether periodic GC is enabled.

**Periodic GC:** Some concrete types accept a `gcInterval: Duration?` at init. When non-nil, a `Task` is started at init that loops indefinitely, sleeping for `gcInterval` then sweeping expired entries. `nil` disables it. Not all storages can be garbage collected in this way, and as such those do not accept `gcInterval`.

The GC task captures `self` weakly and is stored as a property, cancelled in `deinit`. This prevents a retain cycle where the task keeps the cache alive indefinitely. Testable via a weak reference: assign the cache to a `weak var`, let it go out of scope, and assert it is `nil` — which fails if the task holds a strong reference.

**App backgrounding:** When iOS suspends the app, Swift `Task`s are paused at their current suspension point — typically mid-sleep for a GC task. `Task.sleep` accumulates real elapsed time during suspension. On foreground resume, if the configured `gcInterval` has elapsed, the GC sweep fires immediately. No special background task registration is needed; GC is opportunistic and only runs while the app is active.

Implementation-specific mechanics:

- **`StrongMemoryStorage`:** Iterates the backing dictionary and removes entries whose expiry date has passed. O(n) in entry count.

- **`DiskStorage`:** Runs `DELETE FROM entries WHERE expiry IS NOT NULL AND expiry < ?`, passing `Int(now().timeIntervalSince1970)`. This keeps GC behavior consistent with the injected `now` rather than the real wall clock, which matters for testing.

- **`WeakMemoryStorage`:** `NSCache` does not support entry enumeration, so expiry cannot be swept at GC time — only enforced on access. Does not take a `gcInterval`. Expired entries that are never accessed will linger in `NSCache` until the OS evicts them; they are harmless (expiry is checked on read) but not proactively cleaned up.

## Thread Safety

All implementations are safe to call concurrently — reads and writes will not produce data races or corruption.

- **`WeakMemoryStorage`:** `NSCache` is internally thread-safe.
- **`StrongMemoryStorage`:** Protects the backing dictionary with an `NSLock`. All reads and writes acquire the lock.

**`NSLock` is not re-entrant.** Implementations that use `NSLock` must never call a lock-acquiring method while already holding the lock. In practice: `get(_:expiry:through:)` acquires the lock to read, releases, calls `through`, then re-acquires to write — never holding the lock across the `through` call.
- **`DiskStorage`:** GRDB's `DatabaseQueue` serializes all access internally.
- **`TieredStorage`:** Thread safety is provided by each delegate; `TieredStorage` itself holds no mutable state.

**Stampede protection is not provided.** Concurrent `get(_:through:)` calls with the same key on a cold cache may each independently invoke `through`. Callers that require the guarantee must use `CoalescingCache`.

### `CoalescingCache`

An `actor`-based wrapper that guarantees at most one in-flight `through` call per key at any time. Not a drop-in `Cache` conformance — it is a specialized type for call sites that require stampede protection.

```swift
actor CoalescingCache<K: Hashable & Sendable, V: Sendable> {
    private let delegate: any Cache<K, V>
    private var inFlight: [K: Task<V, any Error>] = [:]

    init(delegate: any Cache<K, V>)

    func get(_ key: K, expiry: Expiry? = nil, through: @Sendable () async throws -> V) async throws -> V
}
```

**Behavior:** On a miss, checks `inFlight` for the key. If a task already exists, awaits its result directly — no second `through` invocation. Otherwise creates a `Task` wrapping `through`, stores it in `inFlight`, and awaits it. On completion, removes the task from `inFlight` and — on success — stores the result in the delegate.

Actor isolation makes the check-and-store of `inFlight` atomic across suspension points, closing the TOCTOU gap. Trade-offs:

- `K` and `V` must be `Sendable` (actor boundary requirement).
- The method is unconditionally `throws` — `rethrows` is not expressible when the error comes from a stored `Task` rather than a directly-called closure.
- Only the async path is coalesced. There is no sync `get` variant.
- If `through` throws, all waiting callers receive the error and the key is removed from `inFlight`, so subsequent calls will retry.

## Sendability

The `Cache` protocol is not `Sendable` — caches are service-layer singletons, not values passed between actors.

The concrete implementations are `@unchecked Sendable` for a narrower reason: Swift 6 requires task closure captures to be `Sendable`, so `Task { [weak self] in ... }` in the GC task will not compile unless `self` is `Sendable`. This is a compiler requirement, not an architectural one. The `Cache` protocol and its `K`/`V` type parameters carry no `Sendable` constraints.

`@unchecked Sendable` is a code-review guarantee. The safety invariant: every access to mutable backing state goes through the implementation's synchronization mechanism — `NSCache` + `NSLock` (WeakMemoryStorage), `NSLock` (StrongMemoryStorage), GRDB `DatabaseQueue` (DiskStorage). Keep all backing-store properties `private` and never access them outside the synchronization path.

## Test Plan

Tests go in `MagicCardSearchTests`. `DiskStorage` tests should use a unique `name` per test (e.g. a `UUID` string) so databases don't bleed across cases.

**Controlling time in tests:** All concrete types accept `now: @escaping () -> Date`. To control time, declare a `var testNow = Date()` and pass `{ testNow }`. Advancing `testNow` into the future makes entries appear expired. To trigger a GC sweep without waiting for the timer, call `removeExpiredEntries()` directly (exposed as an internal method for testing). This combination — injectable `now` plus direct sweep invocation — makes all time-dependent behavior deterministic without real sleeps.

### `StrongMemoryStorage` and `WeakMemoryStorage`

- `get` returns `nil` for a missing key
- `get` returns a stored value
- `put` overwrites an existing entry
- `remove` deletes a specific entry without affecting others
- `clear` removes all entries
- `get` returns `nil` and removes an expired entry (use `Expiry.date` in the past)
- `getWithMetadata` returns `nil` for a missing key
- `getWithMetadata` returns the value and correct `expiryDate` for a stored entry
- `getWithMetadata` returns `expiryDate: nil` for entries stored with `Expiry.never`
- `get(_:expiry:through:)` stores and returns the `through` result on a miss
- `get(_:expiry:through:)` returns the cached value without calling `through` on a hit
- `get(_:expiry:through:)` uses the provided expiry when storing (verify by re-getting after that expiry)
- `Expiry.never` entries are never treated as expired
- `countLimit`: inserting beyond the limit evicts entries; expired entries are evicted before non-expired ones (StrongMemoryStorage only — NSCache's limit is a hint)
- Concurrent reads and writes from multiple `Task`s do not produce data races or corrupt stored values

### `DiskStorage`

All of the above, plus:
- A value written by one instance is readable by a new instance with the same `name` (persistence)
- Two instances with different `name`s don't interfere with each other
- `clear` only affects the named database, not other `DiskStorage` instances
- `remove` deletes the row for that key; a subsequent `get` returns `nil`
- GC: store an entry with a future expiry, advance `testNow` past it, call `removeExpiredEntries()` directly, verify the entry is gone
- GC: `Expiry.never` entries survive a GC sweep regardless of how far `testNow` is advanced
- `init?` returns `nil` when the database cannot be created (e.g. an unwritable path)
- GC task does not prevent deallocation: assign cache to a `weak var`, let it go out of scope, assert it is `nil`
- Custom transformer: a value written with a custom `encode`/`decode` round-trips correctly; a decode error is treated as a miss and the row is deleted
- Key decode failure: manually insert a row with a malformed key blob; a subsequent `get` for any key returns `nil` for that row and the row is deleted from the database

### `TieredStorage`

Tests use a `SpyCache<K: Hashable, V>` — a `Cache` conformance defined in the test target that records all calls (`getCalls`, `getWithMetadataCalls`, `putCalls`, `removeCalls`, `clearCallCount`) and backs them with a dictionary. This lets tests assert both return values and which delegates were consulted.

- `get` returns `nil` when all delegates miss
- `get` returns a value found in the first delegate without consulting later delegates (verify tier-2 `getCalls` is empty)
- `get` returns a value found in delegate N and backfills delegates 0..<N (verify via `putCalls` on earlier delegates)
- Backfill respects TTL: a hit with 10s remaining is backfilled at most 10s, not the full delegate default
- Backfill with `Expiry.never`: a hit with no expiry is backfilled with `.never`, not the tier's configured default (verify `putCalls` on the earlier spy carries `expiry: .never`, not `expiry: nil`)
- After a backfill, a subsequent `get` hits the first delegate
- `put` writes to all delegates (verify each spy's `putCalls`)
- `remove` removes from all delegates (verify each spy's `removeCalls`)
- `clear` clears all delegates (verify each spy's `clearCallCount`)

### `Expiry`

- Each `Expiry` case converts to the correct `Date` (seconds/minutes/hours/days arithmetic)
- An entry stored with `Expiry.never` is never considered expired regardless of how far the clock advances

### `CoalescingCache`

- A delegate hit returns immediately without calling `through`
- On a cold miss, `through` is called exactly once even when multiple concurrent callers race for the same key
- A second caller that arrives while the first is in-flight awaits the first's result without calling `through`
- After a successful fetch, the result is stored in the delegate and a subsequent call returns it without invoking `through`
- If `through` throws, all waiting callers receive the error; a subsequent call retries `through`
- Concurrent calls for different keys each invoke their own `through` independently

