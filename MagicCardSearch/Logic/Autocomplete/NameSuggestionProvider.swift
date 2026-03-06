import ScryfallKit
import OSLog
import FuzzyMatch
import Cache

private let logger = Logger(subsystem: "MagicCardSearch", category: "NameSuggestionProvider")

struct NameSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: FilterTerm
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

private func normalizeForCache(_ string: String) -> String {
    string.lowercased().replacing(/[^a-z]/, with: "")
}

actor NameSuggestionProvider {
    private let cache = MemoryStorage<String, [String]>(
        config: .init(expiry: .never, countLimit: 100)
    )

    func getSuggestions(for partial: PartialFilterTerm, in cardNames: [String], limit: Int) -> [NameSuggestion] {
        guard limit > 0 else {
            return []
        }

        let name: String
        let comparison: Comparison?

        switch partial.content {
        case .name(_, let partialValue):
            name = partialValue.incompleteContent
            comparison = nil
        case .filter(let filter, let partialComparison, let partialValue):
            if let completeComparison = partialComparison.toComplete(), filter.lowercased() == "name" && (
                completeComparison == .including || completeComparison == .equal || completeComparison == .notEqual
            ) {
                name = partialValue.incompleteContent
                comparison = completeComparison
            } else {
                name = ""
                comparison = nil
            }
        }

        guard name.count >= 2 else {
            return []
        }

        let normalizedName = normalizeForCache(name)
        let candidates: [String]
        let cacheKeys = cache.allKeys
        let bestPrefix = cacheKeys
            .filter { normalizedName.hasPrefix($0) }
            .max(by: { $0.count < $1.count })

        if let bestPrefix, let cached = try? cache.entry(forKey: bestPrefix).object {
            candidates = cached
        } else {
            candidates = cardNames
        }

        let matcher = FuzzyMatcher()
        let query = matcher.prepare(name)
        var buffer = matcher.makeBuffer()

        // Without the type annotations on this line, the compiler loops forever. Really. Try below:
        //   let results = candidates.compactMap { candidate in
        let start = ContinuousClock().now
        let results: [(String, ScoredMatch)] = candidates.compactMap { candidate -> (String, ScoredMatch)? in
            guard let match = matcher.score(candidate, against: query, buffer: &buffer) else {
                return nil
            }
            return (candidate, match)
        }
        let elapsed = ContinuousClock().now - start
        logger.info("Fuzzy match over \(candidates.count) names took \(elapsed)")

        let start2 = ContinuousClock().now
        let sorted = results.sorted { $0.1.score > $1.1.score }
        let elapsed2 = ContinuousClock().now - start2
        logger.info("Sorting \(results.count) names took \(elapsed2)")

        let matchedNames = sorted.map { $0.0 }
        cache.setObject(matchedNames, forKey: normalizedName)

        return Array(sorted
            .lazy
            .prefix(limit)
            .map { cardName, match in
                let filter: FilterTerm
                if let comparison {
                    filter = .basic(partial.polarity, "name", comparison, cardName)
                } else {
                    filter = .name(partial.polarity, true, cardName)
                }

                // TODO: We can do better than this; we know where it should be!
                let range = filter.description.range(of: name, options: .caseInsensitive)
                return NameSuggestion(
                    filter: filter,
                    matchRange: range,
                    prefixKind: cardName.range(of: name, options: [.caseInsensitive, .anchored]) == nil ? .none : (cardName.contains(" ") || partial.polarity == .negative ? .effective : .actual),
                    suggestionLength: cardName.count,
                )
            }
         )
    }
}
