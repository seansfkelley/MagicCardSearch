import Testing
@testable import MagicCardSearch

@Suite
struct CachingFuzzyMatcherTests {
    private let candidates = [
        "Lightning Bolt",
        "Lightning Greaves",
        "Lightning Helix",
        "Firebolt",
        "Thoughtseize",
        "Counterspell",
    ]

    @Test func returnsOnlyMatchingCandidates() {
        let matcher = CachingFuzzyMatcher(countLimit: 100)
        let results = matcher.match("bolt", in: candidates)
        let names = results.map { $0.0 }.sorted()

        #expect(names == ["Firebolt", "Lightning Bolt"])
    }

    @Test func returnsEmptyForNoMatches() {
        let matcher = CachingFuzzyMatcher(countLimit: 100)
        let results = matcher.match("zzzzzzz", in: candidates)

        #expect(results.isEmpty)
    }

    @Test func resultsAreSortedByDescendingScore() {
        let matcher = CachingFuzzyMatcher(countLimit: 100)
        let results = matcher.match("bolt", in: candidates)
        let scores = results.map { $0.1.score }

        for i in 0..<scores.count - 1 {
            #expect(scores[i] >= scores[i + 1])
        }
    }

    @Test func caseInsensitiveMatching() {
        let matcher = CachingFuzzyMatcher(countLimit: 100)
        let results = matcher.match("BOLT", in: candidates)
        let names = results.map { $0.0 }.sorted()

        #expect(names == ["Firebolt", "Lightning Bolt"])
    }

    @Test func emptyCandidatesReturnsEmpty() {
        let matcher = CachingFuzzyMatcher(countLimit: 100)
        let results = matcher.match("bolt", in: [])

        #expect(results.isEmpty)
    }

    @Test func emptyQueryReturnsAllCandidates() {
        let matcher = CachingFuzzyMatcher(countLimit: 100)
        let results = matcher.match("", in: candidates)
        let names = results.map { $0.0 }.sorted()

        #expect(names == candidates.sorted())
    }
}
