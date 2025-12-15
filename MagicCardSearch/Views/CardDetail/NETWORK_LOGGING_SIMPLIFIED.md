# Network Logging - Simplified Architecture

This project uses **OSLog with Signposts** for network logging, with a clean, lifecycle-managed API that minimizes boilerplate.

## Quick Start

### Wrap any async network operation:

```swift
// Before: Manual logging everywhere
let logState = await NetworkLogger.shared.beginSearch(query: query)
do {
    let result = try await client.search(query: query)
    await NetworkLogger.shared.endSearch(state: logState, resultCount: result.count, hasMore: result.hasMore)
    return result
} catch {
    await NetworkLogger.shared.searchFailed(state: logState, error: error)
    throw error
}

// After: One clean wrapper
return try await withNetworkLogging(.search(query: query)) {
    try await client.search(query: query)
} metadata: { result in
    ["results": result.count, "hasMore": result.hasMore]
}
```

## Architecture

### 1. Request Types (`NetworkRequestType`)

All network operations are represented as enum cases:

```swift
enum NetworkRequestType {
    case search(query: String, page: Int? = nil)
    case cardFetch(id: UUID)
    case rulings(oracleId: String)
    case image(url: String)
    case svg(setCode: String)
}
```

### 2. Lifecycle-Managed Spans (`NetworkRequestSpan`)

An `actor` that automatically manages logging lifecycle:

- **Auto-starts** signpost interval on creation
- **Auto-ends** on success/failure
- **Auto-cleanup** via `deinit` if you forget to end it
- **Thread-safe** via Swift concurrency

```swift
let span = await NetworkRequestSpan.begin(.search(query: "elves"))
// ... do work ...
await span?.end(metadata: ["results": 42])
// or
await span?.fail(error: someError)
```

### 3. Convenience Wrapper (`withNetworkLogging`)

Wraps any throwing async operation with automatic logging:

```swift
func withNetworkLogging<T>(
    _ type: NetworkRequestType,
    fromCache: Bool = false,
    metadata: @escaping (T) -> [String: Any] = { _ in [:] },
    operation: () async throws -> T
) async rethrows -> T
```

**Features:**
- Automatically begins span
- Automatically ends on success with optional metadata
- Automatically logs failure on error
- Propagates both success values and errors

## Usage Examples

### Search Request

```swift
func search(query: String) async throws -> SearchResult {
    return try await withNetworkLogging(.search(query: query)) {
        try await client.searchCards(query: query)
    } metadata: { result in
        ["results": result.cards.count, "hasMore": result.nextPageURL != nil]
    }
}
```

### Card Fetch

```swift
func fetchCard(byId id: UUID) async throws -> Card {
    return try await withNetworkLogging(.cardFetch(id: id)) {
        try await client.getCard(identifier: .scryfallID(id: id.uuidString))
    } metadata: { card in
        ["name": card.name]
    }
}
```

### Rulings with Cache Detection

```swift
func fetchRulings(oracleId: String) async throws -> [Card.Ruling] {
    // Check cache first
    if let cached = cache.object(forKey: oracleId) {
        _ = await NetworkRequestSpan.begin(.rulings(oracleId: oracleId), fromCache: true)
        return cached.rulings
    }
    
    // Network request with logging
    return try await withNetworkLogging(.rulings(oracleId: oracleId)) {
        try await client.getRulings(oracleId)
    } metadata: { rulings in
        ["count": rulings.count]
    }
}
```

### SVG Loading

```swift
private func loadSVG(setCode: String) async throws -> Data {
    return try await withNetworkLogging(.svg(setCode: setCode)) {
        let (data, _) = try await URLSession.shared.data(from: url)
        return data
    } metadata: { data in
        ["bytes": data.count]
    }
}
```

### AsyncImage (Automatic with LoggedAsyncImage)

```swift
// Just replace AsyncImage with LoggedAsyncImage - that's it!
LoggedAsyncImage(url: cardImageURL) { phase in
    if let image = phase.image {
        image.resizable()
    } else {
        ProgressView()
    }
}
```

## Console Output

```
🔍 Starting search: is:commander [2024-12-14 10:30:15.123]
✅ Complete: search: is:commander results: 25, hasMore: true [125.3ms]

🃏 Starting card: 550c74d4-... [2024-12-14 10:30:16.001]
✅ Complete: card: 550c74d4-... name: Atraxa [89.7ms]

💾 💾 From cache: rulings: 550c74d4-...

🖼️ Starting image: https://cards.scryfall.io/... [2024-12-14 10:30:16.210]
✅ Complete: image: https://cards.scryfall.io/... [342.1ms]

🎨 Starting svg: khm [2024-12-14 10:30:17.005]
✅ Complete: svg: khm bytes: 2048 [45.2ms]
```

## Instruments Integration

All requests create signposts visible in Instruments:

1. **Product > Profile** (⌘I)
2. Select **Logging** template
3. Record while using the app
4. View timeline with:
   - "Search" intervals
   - "Card Fetch" intervals
   - "Rulings" intervals
   - "Image Load" intervals
   - "SVG Load" intervals

## Benefits Over Manual Approach

| Feature | Manual | New System |
|---------|--------|------------|
| Lines of code | 10-15 per call site | 3-5 per call site |
| Error handling | Manual try/catch | Automatic |
| Cleanup | Manual in every path | Automatic via deinit |
| Thread safety | Requires @MainActor | Actor-isolated |
| Metadata | Hard-coded strings | Type-safe enums |
| Cache detection | Manual everywhere | One line |
| Consistency | Easy to forget | Guaranteed by wrapper |

## Adding New Request Types

1. Add case to `NetworkRequestType`:
```swift
case myNewRequest(param: String)
```

2. Add display properties:
```swift
var description: String {
    // ...
    case .myNewRequest(let param): return "my-request: \(param)"
}

var emoji: String {
    // ...
    case .myNewRequest: return "🎯"
}
```

3. Use it:
```swift
return try await withNetworkLogging(.myNewRequest(param: "test")) {
    try await doWork()
}
```

That's it! No new logger classes, no new methods, no manual cleanup.

## Performance

- **Zero overhead** when not actively profiling
- **Compile-time optimized** by Swift compiler
- **Actor-isolated** for thread safety without locks
- **Automatic cleanup** prevents leaks
- **Lazy metadata** - only computed on success

## Future Enhancements

Easy to add without changing call sites:

- Network quality detection
- Retry counting
- Request deduplication tracking
- Rate limit detection
- Automatic performance regression alerts
