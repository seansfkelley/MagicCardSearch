# Cache Design

A replacement for the third-party `Cache` package. Motivation: testability (mockable conformances), simpler call-site ergonomics (cache-aside `get(_:through:)` pattern), and cleaner semantics.

**Do not integrate into the app until the standalone implementation is complete and reviewed.**

## API

```swift
enum Expiry {
    case never
    case date(Date)
    case seconds(Int)
    case minutes(Int)
    case hours(Int)
    case days(Int)
}
// Sub-second resolution is not supported.

protocol Cache<K, V> {
    func get(_ key: K) -> V?
    func get(_ key: K, expiry: Expiry?, through: () throws -> V) rethrows -> V
    func get(_ key: K, expiry: Expiry?, through: () async throws -> V) async rethrows -> V
    func put(_ key: K, _ value: V, expiry: Expiry?)
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
    init(expiry: Expiry?, countLimit: Int? = nil, clock: some Clock = ContinuousClock())
}
class StrongMemoryStorage<K: Hashable, V>: Cache<K, V> {
    init(expiry: Expiry?, countLimit: Int? = nil, gcInterval: Duration? = .seconds(300), clock: some Clock = ContinuousClock())
}
class DiskStorage<K: Codable & Hashable, V: Codable>: Cache<K, V> {
    init?(expiry: Expiry?, name: String, countLimit: Int? = nil, gcInterval: Duration? = .seconds(300), clock: some Clock = ContinuousClock())
}
class TieredStorage<K, V>: Cache<K, V> {
    init(delegates: [any Cache<K, V>])
}
```

The `expiry` parameter on `get(_:expiry:through:)` overrides the storage's default expiry for that specific entry. Passing `nil` uses the storage's configured default.

**Backing store errors are not surfaced.** A cache is never the source of truth, so a read error (disk I/O failure, decode failure, etc.) is semantically equivalent to a miss — callers cannot meaningfully handle it differently from a miss anyway. Read errors are logged internally and treated as misses; the `through` closure is called as normal. Write errors (`put`, backfill) are also logged and dropped — the caller already has the value and can use it regardless of whether it was cached. This keeps the entire protocol free of `throws`.

## Implementations

### `WeakMemoryStorage`

Backed by `NSCache`. The OS may evict entries under memory pressure. Does not support costs. Suitable as a best-effort memory tier that doesn't grow unboundedly. `countLimit` is passed directly to `NSCache.countLimit` — it is a hint, not a hard cap; the OS may evict earlier or later.

### `StrongMemoryStorage`

Backed by a `Dictionary`. Entries are never evicted by the OS. Suitable when values must survive memory pressure (e.g. expensive-to-fetch data where a miss is costly). `countLimit` is a hint, not a hard cap. On write, if `count > countLimit * 2`, a linear scan runs: expired entries are removed first, then entries with the soonest remaining TTL until under `countLimit` (`Expiry.never` entries are last to go). This batches the O(n) cleanup cost — frequent inserts near the limit don't trigger a scan on every write. If all entries are `Expiry.never`, which ones are evicted is nondeterministic — this is an explicit limitation.

### `DiskStorage`

Failable init — returns `nil` if the SQLite database cannot be opened or created (e.g. disk full, permissions error). Callers should handle the nil case, typically by falling back to a memory-only cache.

Backed by a dedicated SQLite database (via GRDB) per `DiskStorage` instance, stored in the app's Caches directory as `<name>.sqlite`. Separate databases mean concurrent writes to different caches (e.g. cards vs. searches) never contend — SQLite serializes writes per connection, so a shared database would turn independent cache operations into a bottleneck. Schema:

```sql
CREATE TABLE IF NOT EXISTS entries (
    key    BLOB    NOT NULL PRIMARY KEY,
    value  BLOB    NOT NULL,
    expiry INTEGER          -- Unix timestamp (seconds), NULL means never expires
);
```

This runs on every init and is a no-op if the table already exists. No migration system is needed — the database is purely a cache and can be deleted at any time without data loss.

**Count limit:** `countLimit` is a hint, not a hard cap. On write, if `count > countLimit * 2`, a cleanup runs: delete expired entries first, then the soonest-expiring entries until under `countLimit`. `Expiry.never` entries are last to be evicted. If all entries are `Expiry.never`, which ones are evicted is nondeterministic — this is an explicit limitation.

**Key serialization:** `K: Codable`, encoded to `Data` and stored as a `BLOB`. The encoding **must be stable across app versions** — if the serialized form of a key changes, prior entries for that key become unreachable (treated as misses). This holds for `String`, `UUID`, `Int`, and synthesized `Codable` structs/enums with stable field names. Types whose serialized form is non-deterministic or whose `Codable` synthesis may change between builds should not be used as `DiskStorage` keys. If a row's key fails to decode (e.g. after a key type change), the row is deleted.

**Value serialization:** `V: Codable`, encoded to `Data` and stored as a blob.

### `TieredStorage`

Wraps an ordered list of `Cache` delegates (fastest first, e.g. memory before disk). Imposes no constraints on `K` or `V` — each delegate was already constructed with its own constraints.

**Read behavior:** Check delegates in order. On a hit in delegate N, backfill all preceding delegates (0..<N) with the found value using `min(remaining TTL of the found entry, delegate's default expiry)` — so a nearly-expired entry is not backfilled with a longer TTL than it has remaining.

**Write behavior (`put`):** Write through to all delegates.

**Clear behavior:** Clears all delegates.

## Expiry & Garbage Collection

**On access:** All implementations check expiry on every `get`. If the retrieved entry is expired, it is deleted and `nil` is returned, regardless of whether periodic GC is enabled.

**Periodic GC:** Each concrete type (not `TieredStorage`) accepts a `gcInterval: Duration?` at init. When non-nil, a `Task` is started at init that loops indefinitely, sleeping for `gcInterval` then sweeping expired entries. `nil` disables it. `TieredStorage` does not have its own GC — its delegates each run their own.

The GC task captures `self` weakly and is stored as a property, cancelled in `deinit`. This prevents a retain cycle where the task keeps the cache alive indefinitely. Testable via a weak reference: assign the cache to a `weak var`, let it go out of scope, and assert it is `nil` — which fails if the task holds a strong reference.

Implementation-specific mechanics:

- **`StrongMemoryStorage`:** Iterates the backing dictionary and removes entries whose expiry date has passed. O(n) in entry count.

- **`DiskStorage`:** Runs `DELETE FROM entries WHERE expiry IS NOT NULL AND expiry < unixepoch('now')` — a single indexed query.

- **`WeakMemoryStorage`:** `NSCache` does not support entry enumeration, so expiry cannot be enforced at GC time — only on access. Does not take a `gcInterval`. Expired entries that are never accessed will remain until evicted by the OS.

## Thread Safety

All implementations are safe to call concurrently — reads and writes will not produce data races or corruption.

- **`WeakMemoryStorage`:** `NSCache` is internally thread-safe.
- **`StrongMemoryStorage`:** Protects the backing dictionary with an `NSLock`. All reads and writes acquire the lock.
- **`DiskStorage`:** GRDB's `DatabaseQueue` serializes all access internally.
- **`TieredStorage`:** Thread safety is provided by each delegate; `TieredStorage` itself holds no mutable state.

**Stampede protection is not provided.** Concurrent `get(_:through:)` calls with the same key on a cold cache may each independently invoke `through`. This is an accepted limitation — closing it would require coalescing in-flight tasks per key, which breaks `rethrows` and adds significant complexity. Current app usage is `@MainActor`, so stampedes cannot occur in practice.

## Sendability

The `Cache` protocol is not `Sendable` — caches are service-layer singletons, not values passed between actors.

The concrete implementations are `@unchecked Sendable` for a narrower reason: Swift 6 requires task closure captures to be `Sendable`, so `Task { [weak self] in ... }` in the GC task will not compile unless `self` is `Sendable`. This is a compiler requirement, not an architectural one. The `Cache` protocol and its `K`/`V` type parameters carry no `Sendable` constraints.

`@unchecked Sendable` is a code-review guarantee. The safety invariant: every access to mutable backing state goes through the implementation's synchronization mechanism — `NSCache` (WeakMemoryStorage), `NSLock` (StrongMemoryStorage), GRDB `DatabaseQueue` (DiskStorage). Keep all backing-store properties `private` and never access them outside the synchronization path.

## Test Plan

Tests go in `MagicCardSearchTests`. Inject a `TestClock` to control time without sleeping. `DiskStorage` tests should use a unique `name` per test (e.g. a `UUID` string) so databases don't bleed across cases.

### `StrongMemoryStorage` and `WeakMemoryStorage`

- `get` returns `nil` for a missing key
- `get` returns a stored value
- `put` overwrites an existing entry
- `clear` removes all entries
- `get` returns `nil` and removes an expired entry (use `Expiry.date` in the past)
- `get(_:expiry:through:)` stores and returns the `through` result on a miss
- `get(_:expiry:through:)` returns the cached value without calling `through` on a hit
- `get(_:expiry:through:)` uses the provided expiry when storing (verify by re-getting after that expiry)
- `Expiry.never` entries are never treated as expired
- `countLimit`: inserting beyond the limit evicts entries; expired entries are evicted before non-expired ones (StrongMemoryStorage only — NSCache's limit is a hint)

### `DiskStorage`

All of the above, plus:
- A value written by one instance is readable by a new instance with the same `name` (persistence)
- Two instances with different `name`s don't interfere with each other
- `clear` only affects the named database, not other `DiskStorage` instances
- GC: advance `now` past expiry, trigger a GC sweep directly (expose an internal `removeExpiredEntries()` method for testing), verify expired entries are gone
- GC task does not prevent deallocation: assign cache to a `weak var`, let it go out of scope, assert it is `nil`

### `TieredStorage`

Tests use a `SpyCache<K: Hashable, V>` — a `Cache` conformance defined in the test target that records all calls (`getCalls`, `putCalls`, `clearCallCount`) and backs them with a dictionary. This lets tests assert both return values and which delegates were consulted.

- `get` returns `nil` when all delegates miss
- `get` returns a value found in the first delegate without consulting later delegates (verify tier-2 `getCalls` is empty)
- `get` returns a value found in delegate N and backfills delegates 0..<N (verify via `putCalls` on earlier delegates)
- After a backfill, a subsequent `get` hits the first delegate
- `put` writes to all delegates (verify each spy's `putCalls`)
- `clear` clears all delegates (verify each spy's `clearCallCount`)

### `Expiry`

- Each `Expiry` case converts to the correct `Date` (seconds/minutes/hours/days arithmetic)
- An entry stored with `Expiry.never` is never considered expired regardless of how far the clock advances

