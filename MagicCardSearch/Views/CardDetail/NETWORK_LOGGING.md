# Network Logging and Profiling

This project uses **OSLog with Signposts** for comprehensive network logging and performance profiling. This is Apple's native unified logging system and provides the best integration with Xcode's debugging tools.

## Overview

All network requests in the app are now instrumented with:
- **Detailed logging** showing what's happening at the network level
- **Performance measurement** using signposts to track request duration
- **Request counting** to see how many concurrent requests are active
- **Cache detection** to distinguish cached vs. network requests

## Logging Categories

Network activity is organized into four categories:

1. **Search** (`com.magicccardsearch.app.search`)
   - Card searches
   - Pagination
   - Individual card fetches

2. **Rulings** (`com.magicccardsearch.app.rulings`)
   - Card rulings lookups
   - Cache hits/misses

3. **Images** (`com.magicccardsearch.app.images`)
   - Card image downloads via AsyncImage
   - All card face images

4. **SVG** (`com.magicccardsearch.app.svg`)
   - Set icon downloads
   - SVG parsing and rendering

## Viewing Logs in Xcode

### Console Logs

1. Run your app in Xcode
2. Open the Debug area (⌘⇧Y)
3. Look for log messages with emojis:
   - 🔍 Search starting
   - ✅ Success
   - ❌ Failure
   - 🃏 Card fetch
   - 📖 Rulings
   - 🖼️ Image load
   - 🎨 SVG load
   - 💾 Cache hit

Example output:
```
🔍 Starting search: is:commander [Active: 1]
✅ Search complete: 25 results (has more pages) [Active: 0]
🖼️ Loading image: https://cards.scryfall.io/... [Active: 3]
💾 SVG from cache: khm
```

### Filtering Console Output

Filter the console to see specific categories:
- `category:search` - Only search requests
- `category:rulings` - Only rulings requests
- `category:images` - Only image loads
- `category:svg` - Only SVG loads
- `subsystem:com.magicccardsearch.app` - All network activity

## Performance Profiling with Instruments

For detailed performance analysis, use Instruments:

### Using Instruments App

1. In Xcode, choose **Product > Profile** (⌘I)
2. Select the **Logging** template
3. Click Record to start profiling
4. Use your app to perform network operations
5. Stop recording

### Viewing Signposts

Signposts appear in the Instruments timeline showing:
- **Duration** of each network request
- **Concurrent requests** running at the same time
- **Visual timeline** of all network activity

The signpost names are:
- "Search Request" - Card searches
- "Card Fetch" - Individual card lookups
- "Rulings Fetch" - Rulings API calls
- "Image Load" - Card image downloads
- "SVG Load" - Set icon downloads

### Finding Slow Requests

1. In Instruments, look for long horizontal bars in the timeline
2. Click on a signpost to see details:
   - Start time
   - Duration
   - Associated log messages
3. Sort by duration to find the slowest requests

## Debugging Network Issues

### Check Active Request Counts

The logger tracks active requests in real-time. Look for the `[Active: N]` suffix in log messages to see:
- How many requests are running concurrently
- If requests are getting "stuck" (count doesn't decrease)
- Request patterns (bursts, steady state, etc.)

### Identify Cache Misses

Look for `💾` emoji in logs - these indicate cache hits. If you're not seeing cache hits where you expect them:
1. Check the cache implementation
2. Verify cache keys are correct
3. Look for cache eviction issues

### Find Failing Requests

Search console for `❌` to find all failed requests. Each failure includes:
- The URL or query that failed
- The error message
- The active request count when it failed

## Code Integration

### CardSearchService

All search operations are logged:
```swift
func search(filters: [SearchFilter], config: SearchConfiguration) async throws -> SearchResult {
    let logState = await NetworkLogger.shared.beginSearch(query: queryString)
    // ... perform search ...
    await NetworkLogger.shared.endSearch(state: logState, resultCount: count, hasMore: hasMore)
}
```

### RulingsService

Rulings fetches distinguish cache hits from network requests:
```swift
func fetchRulings(from urlString: String, oracleId: String? = nil) async throws -> [Card.Ruling] {
    // Check cache first
    if let cached = cache.object(forKey: cacheKey) {
        _ = await NetworkLogger.shared.beginRulingsFetch(oracleId: oracleId, fromCache: true)
        return cached.rulings
    }
    // ... fetch from network with logging ...
}
```

### SetIconView

SVG loading with full instrumentation:
```swift
private func loadAndRenderSVG() async {
    let logState = await NetworkLogger.shared.beginSVGLoad(setCode: setCode, fromCache: false)
    // ... download and render SVG ...
    await NetworkLogger.shared.endSVGLoad(state: logState, setCode: setCode, bytes: data.count)
}
```

### LoggedAsyncImage

A SwiftUI wrapper that automatically logs AsyncImage loads:
```swift
// Use this instead of AsyncImage
LoggedAsyncImage(url: imageURL) { phase in
    if let image = phase.image {
        image.resizable()
    } else {
        ProgressView()
    }
}
```

## Performance Best Practices

Based on the logging, you can optimize:

1. **Reduce concurrent requests**: If you see [Active: 50+], consider throttling
2. **Improve caching**: Look for repeated requests to the same resources
3. **Batch operations**: Group multiple single requests into batch API calls
4. **Lazy loading**: Delay non-critical requests until needed
5. **Image sizing**: Use appropriate image quality/size for the context

## Troubleshooting

### Logs not appearing

- Make sure you're running in Debug configuration
- Check that the console is showing the correct device/simulator
- Try filtering by `subsystem:com.magicccardsearch.app`

### Signposts not appearing in Instruments

- Make sure you selected the "Logging" template
- In the recording settings, ensure "os_signpost" is enabled
- Check that your deployment target is iOS 15.0+ (signposts require this)

### Active request count incorrect

This could indicate:
- An exception thrown without proper cleanup
- A code path that calls `begin*` but not `end*`
- Check for early returns that skip the end logging call

## Future Enhancements

Potential additions to the logging system:

- Response size tracking (bytes downloaded)
- Network quality indicators (slow vs. fast connections)
- Retry attempt counting
- Rate limiting detection
- API quota usage tracking
- Custom Instruments package for even better visualization

## Additional Resources

- [Apple Documentation: Logging](https://developer.apple.com/documentation/os/logging)
- [Apple Documentation: Measuring Performance](https://developer.apple.com/documentation/os/logging/measuring_performance_with_signposts)
- [WWDC Videos on Unified Logging](https://developer.apple.com/videos/play/wwdc2020/10168/)
