# Throttling Design Proposal

## Context

`CachingScryfallService` wraps a `ScryfallClient` and makes outbound HTTP calls to Scryfall's API. Despite the caching layer, cache misses result in real network requests. Scryfall enforces rate limits and issues 30-second bans on violation; repeated violations can result in a permanent block.

Actual Scryfall rate limits (from https://scryfall.com/docs/api/rate-limits):

| Endpoints | Limit |
|---|---|
| `/cards/search`, `/cards/named`, `/cards/random`, `/cards/collection` | **2 req/s** |
| All other endpoints | **10 req/s** |

Note: the user-supplied target of "10 req/s" covers the less-restricted endpoints, but the search and random endpoints—which are the highest-traffic ones in this app—are actually capped at 2 req/s. The throttle system must handle both limits.

---

## Algorithms Considered

### Fixed Window

Divides time into discrete windows (e.g., 1-second buckets) and counts requests in the current bucket. Simplest to implement.

**Rejected because:** The boundary burst problem makes it unreliable for hard limits. A client can issue N requests at t=0.99s and N more at t=1.01s, firing 2N requests across two windows within ~20ms. This is a fundamental flaw, not an edge case; it would regularly violate Scryfall's limits during bursts.

### Token Bucket (e.g., `pfandrade/TokenBucket`)

A bucket holds up to `capacity` tokens. Tokens refill at a fixed rate. Each request consumes one token; when empty, callers wait until a token is available. Allows bursts up to `capacity`.

**Rejected because:**
1. The burst property cuts against the hard limit guarantee. With capacity = 10 and refill rate = 10/s, a caller can consume 10 tokens at t=0.9s, then 10 more at t=1.0s when the bucket refills—firing 20 requests within 100ms. This violates a "never more than 10 per rolling second" constraint.
2. The only maintained Swift implementation (`pfandrade/TokenBucket`) uses `NSCondition` with thread-blocking semantics, which is **unsafe to use with Swift Concurrency**. Blocking a thread inside an `async` context can starve the cooperative thread pool and cause deadlocks.
3. A from-scratch actor-based token bucket requires careful handling of actor reentrancy: tokens must be decremented before any `await` point, and invariants re-validated after every suspension. This complexity is not warranted when a simpler correct approach exists.

### Leaky Bucket

Requests queue in a FIFO buffer and are dispatched at a constant, metered rate. No bursting—dispatch rate is completely flat.

**Rejected because:** The constant-drain property creates artificial queuing latency even when the app is well within its rate budget. In a user-facing iOS app, a user opening a card detail page should not have to wait behind unrelated in-flight requests just because the leaky bucket's output clock hasn't ticked yet. Good UX for a power-user app requires low latency on fresh requests, not perfectly uniform dispatch pacing.

### Swift Async Algorithms `throttle`

The `throttle(for:)` operator on `AsyncSequence` ensures a minimum interval between emitted values.

**Rejected because:**
1. It is a *filtering/dropping* operator: elements that arrive too quickly are discarded, not queued. Dropping network requests is not acceptable—callers need to either receive a response or receive an error, not be silently ignored.
2. It has a documented "lost wakeup" bug: after the throttle interval closes, no element is forwarded until the *next* new element arrives. This makes it unreliable even for its intended purpose.
3. The abstraction is designed for consuming fast event streams, not pacing outbound HTTP calls.

### Concurrency Limiting (AsyncSemaphore / Dave DeLong's `Throttle`)

Limits the number of requests *in-flight simultaneously*. `groue/Semaphore` provides `AsyncSemaphore`, the correct Swift Concurrency version (does not block threads).

**Rejected as the primary mechanism because:** This controls concurrency, not time-based rate. If Scryfall responds in 50ms, a semaphore with value 10 permits up to 200 req/s. It can *complement* time-based rate limiting (to also cap concurrent connections), but cannot replace it.

### Sliding Window Log

Maintains a log of timestamps for recent requests. Before each request, purge entries older than the window duration and check the count. If count < limit, record the timestamp and proceed. Otherwise, sleep until the oldest entry ages out of the window, then re-evaluate.

**Recommended.** See below.

---

## Recommended Approach: Actor-Based Sliding Window Log

### Why

The sliding window log is the only algorithm that provides a true, non-approximate guarantee of "no more than N requests in any rolling W-second window." Unlike fixed window, it has no boundary burst vulnerability. Unlike token bucket, it does not allow accumulated idle capacity to produce bursts. Unlike leaky bucket, it does not impose artificial latency when the app is well under its limit.

For this application, the log has trivially low memory overhead: since the limit is at most 10, the log holds at most 10 timestamps at any given time. There is no meaningful storage cost.

The algorithm maps cleanly onto Swift's actor model:
- The actor serializes all access, so no locks or `DispatchSemaphore` are needed.
- Actor reentrancy is safe because the loop re-evaluates state after every `await` suspension—any other callers that ran during the sleep are accounted for when the loop resumes.
- `Task.sleep(until:clock:)` with `ContinuousClock` is the correct async-native sleep API; it does not block a thread.

### Sketch

```swift
actor RateLimiter {
    private let maxRequests: Int
    private let windowDuration: Duration
    private var log: [ContinuousClock.Instant] = []

    init(maxRequests: Int, windowDuration: Duration = .seconds(1)) {
        self.maxRequests = maxRequests
        self.windowDuration = windowDuration
    }

    func waitForSlot() async throws {
        while true {
            let now = ContinuousClock.now
            log.removeAll { now - $0 >= windowDuration }

            if log.count < maxRequests {
                log.append(now)
                return
            }

            // Sleep until the oldest entry exits the window, plus a small margin
            // for ContinuousClock precision. The loop re-evaluates after waking,
            // which correctly handles concurrent waiters that also woke up.
            let sleepUntil = log[0] + windowDuration + .milliseconds(1)
            try await Task.sleep(until: sleepUntil, clock: .continuous)
        }
    }
}
```

`waitForSlot()` is called **after** the cache check and **before** the network call, so cached responses do not consume rate limit budget.

### Handling Scryfall's Two-Tier Limits

Because search/random endpoints have a 2 req/s limit while all other endpoints have a 10 req/s limit, `CachingScryfallService` should hold **two limiter instances**:

```swift
private let searchLimiter = RateLimiter(maxRequests: 2)   // /cards/search, /cards/random
private let fetchLimiter  = RateLimiter(maxRequests: 10)  // /cards/{id}, /cards/{id}/rulings, etc.
```

Callers on the search path (`searchCards`, `randomCard`, and the `fetchCard(byOracleId:)` / `fetchCard(byIllustrationId:)` / `fetchCard(byPrintingId:)` methods that use `searchCards` internally) use `searchLimiter`. Calls to `getCard(identifier:)` and `getRulings` use `fetchLimiter`.

### Tweakable Parameters

The following are the primary tuning knobs:

| Parameter | Default | Description |
|---|---|---|
| `maxRequests` (search limiter) | `2` | Max requests per window for search/random endpoints |
| `maxRequests` (fetch limiter) | `10` | Max requests per window for fetch/rulings endpoints |
| `windowDuration` | `.seconds(1)` | The rolling window size (both limiters) |
| Sleep margin | `1ms` | Extra padding past the expiry point to absorb clock imprecision |

Setting `windowDuration` narrower than 1 second (e.g., `.milliseconds(500)` with `maxRequests: 1`) produces a stricter spacing requirement. Setting it wider with a proportionally higher `maxRequests` produces the same average rate with more burst tolerance.

### Interaction with Cancellation

`Task.sleep(until:clock:)` throws `CancellationError` when the task is cancelled. `waitForSlot()` should propagate this (`throws`), so that cancelling a search (e.g., when the user types a new query) does not leave the caller stuck in the rate-limit queue indefinitely.

### What Is Not Needed

- **`groue/Semaphore`** (concurrent request cap): With caching in place and a time-based rate limiter ensuring spacing, concurrent in-flight requests will rarely if ever hit double digits. Adding a concurrency cap would add complexity with no realistic benefit for this app's traffic patterns.
- **Retry on 429**: The rate limiter's purpose is to prevent 429 responses from ever occurring. Retry logic for 429 is a reasonable defensive fallback but is out of scope for this proposal.
