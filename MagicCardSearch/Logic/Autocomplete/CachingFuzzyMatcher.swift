import OSLog
import FuzzyMatch
import Cache

private let logger = Logger(subsystem: "MagicCardSearch", category: "CachingFuzzyMatcher")

func timed<T>(_ work: () throws -> T) rethrows -> (T, Duration) {
    let clock = ContinuousClock()
    let start = clock.now
    let result = try work()
    return (result, clock.now - start)
}

private func normalizeForCache(_ string: String) -> String {
    string.lowercased().replacing(/[^a-z]/, with: "")
}

struct CachingFuzzyMatcher {
    private let cache: MemoryStorage<String, [String]>
    private let matcher = FuzzyMatcher()

    init(countLimit: UInt) {
        cache = MemoryStorage<String, [String]>(
            config: .init(expiry: .never, countLimit: countLimit)
        )
    }

    /// Fuzzy-matches `name` against `cardNames`, returning matched names sorted by score.
    /// Results are cached by normalized name to accelerate subsequent queries that share a prefix.
    func match(_ query: String, in candidates: [String]) -> [(String, ScoredMatch)] {
        let normalizedQuery = normalizeForCache(query)
        let narrowestCachedPrefix = cache.allKeys
            .filter { normalizedQuery.hasPrefix($0) }
            .max { $0.count < $1.count }

        let selectedCandidates = if let narrowestCachedPrefix, let cached = try? cache.entry(forKey: narrowestCachedPrefix).object {
            cached
        } else {
            candidates
        }

        let query = matcher.prepare(query)
        var buffer = matcher.makeBuffer()

        // Without the type annotations on this line, the compiler loops forever. Really. Try below:
        //   let results = candidates.compactMap { candidate in
        let (results, matchDuration): ([(String, ScoredMatch)], Duration) = timed {
            selectedCandidates.compactMap { candidate -> (String, ScoredMatch)? in
                guard let match = matcher.score(candidate, against: query, buffer: &buffer) else {
                    return nil
                }
                return (candidate, match)
            }
        }
        logger.trace("Fuzzy matching count=\(selectedCandidates.count) candidates took duration=\(matchDuration)")

        let (sorted, sortDuration) = timed {
            results.sorted { $0.1.score > $1.1.score }
        }
        logger.trace("Sorting count=\(results.count) matches took duration=\(sortDuration)")

        cache.setObject(sorted.map { $0.0 }, forKey: normalizedQuery)

        return sorted
    }
}
