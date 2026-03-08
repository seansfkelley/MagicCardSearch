import Testing
import Foundation
import SQLiteData
import DependenciesTestSupport
@testable import MagicCardSearch

// MARK: - filterHistorySuggestions

@Suite(.dependency(\.defaultDatabase, try appDatabase()))
@MainActor
class FilterHistorySuggestionsTests {
    @Dependency(\.defaultDatabase) var database

    private func record(filter: FilterQuery<FilterTerm>, atOffset interval: TimeInterval) {
        try? database.write { db in
            try FilterHistoryEntry
                .insert {
                    FilterHistoryEntry(
                        filter: filter,
                        at: Date(timeIntervalSinceReferenceDate: interval),
                    )
                }
                .execute(db)
        }
    }

    private func fetchHistory() -> [FilterHistoryEntry] {
        try! database.read { db in
            try FilterHistoryEntry
                .order { $0.lastUsedAt.desc() }
                .fetchAll(db)
        }
    }

    private func extractFilters(_ suggestions: [AutocompleteSuggestion]) -> [FilterQuery<FilterTerm>] {
        suggestions.compactMap {
            if case .filter(let highlighted) = $0.content { highlighted.value } else { nil }
        }
    }

    @Test("returns no results with no history recorded")
    func emptySuggestions() {
        let suggestions = Array(filterHistorySuggestions(for: "", from: fetchHistory()).prefix(10))
        #expect(suggestions.isEmpty)
    }

    @Test("returns all filters below the limit if no search term is provided")
    func emptySearchText() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)

        let suggestions = Array(filterHistorySuggestions(for: "", from: fetchHistory()).prefix(1))
        let filters = extractFilters(suggestions)
        #expect(filters == [oracleFilter])
    }

    @Test("returns any filters whose string representation has any substring match")
    func substringMatch() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))
        let setFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "set", .equal, "odyssey"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)
        record(filter: setFilter, atOffset: 2000)

        let suggestions = Array(filterHistorySuggestions(for: "y", from: fetchHistory()).prefix(10))
        let filters = extractFilters(suggestions)
        #expect(filters == [setFilter, oracleFilter])
    }

    @Test("returns the empty list if there is no simple substring match in the stringified filters")
    func noSubstringMatch() {
        let colorFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let oracleFilter = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))

        record(filter: colorFilter, atOffset: 0)
        record(filter: oracleFilter, atOffset: 1000)

        let suggestions = Array(filterHistorySuggestions(for: "xyz", from: fetchHistory()).prefix(10))
        #expect(suggestions.isEmpty)
    }
}

// MARK: - enumerationSuggestions

private let emptyCatalogData = EnumerationCatalogData(
    catalogs: [:],
    sets: nil,
    artTags: nil,
    oracleTags: nil
)

@Suite
struct EnumerationSuggestionsTests {
    private func extractFilters(_ suggestions: [AutocompleteSuggestion]) -> [FilterQuery<FilterTerm>] {
        suggestions.compactMap {
            if case .filter(let highlighted) = $0.content { highlighted.value } else { nil }
        }
    }

    @Test<[(PartialFilterTerm, [FilterQuery<FilterTerm>])]>("enumerationSuggestions", arguments: [
        (
            // gives all values, in alphabetical order, if no value part is given
            PartialFilterTerm(polarity: .positive, content: .filter("manavalue", .equal, .bare(""))),
            [
                .term(FilterTerm.basic(.positive, "manavalue", .equal, "even")),
                .term(FilterTerm.basic(.positive, "manavalue", .equal, "odd")),
            ]
        ),
        (
            // narrows based on substring match, preferring shorter strings when they are both prefixes
            PartialFilterTerm(polarity: .positive, content: .filter("is", .including, .bare("scry"))),
            [
                .term(FilterTerm.basic(.positive, "is", .including, "scryland")),
                .term(FilterTerm.basic(.positive, "is", .including, "scryfallpreview")),
            ]
        ),
        (
            // narrows with any substring, not just prefix, also, doesn't care about operator
            PartialFilterTerm(polarity: .positive, content: .filter("format", .greaterThanOrEqual, .bare("less"))),
            [
                .term(FilterTerm.basic(.positive, "format", .greaterThanOrEqual, "timeless")),
            ]
        ),
        (
            // the negation operator is preserved
            PartialFilterTerm(polarity: .negative, content: .filter("is", .including, .bare("scry"))),
            [
                .term(FilterTerm.basic(.negative, "is", .including, "scryland")),
                .term(FilterTerm.basic(.negative, "is", .including, "scryfallpreview")),
            ]
        ),
        (
            // case-insensitive
            PartialFilterTerm(polarity: .positive, content: .filter("foRMat", .greaterThanOrEqual, .bare("lESs"))),
            [
                .term(FilterTerm.basic(.positive, "format", .greaterThanOrEqual, "timeless")),
            ]
        ),
        (
            // non-enumerable filter type yields no options
            PartialFilterTerm(polarity: .positive, content: .filter("oracle", .equal, .bare(""))),
            []
        ),
        (
            // incomplete filter types yield no suggestions
            PartialFilterTerm(polarity: .positive, content: .name(false, .bare("form"))),
            []
        ),
        (
            // unknown filter types yield no suggestions
            PartialFilterTerm(polarity: .positive, content: .filter("foobar", .including, .bare(""))),
            []
        ),
        (
            // incomplete operator is not completeable
            PartialFilterTerm(polarity: .positive, content: .filter("format", .incompleteNotEqual, .bare(""))),
            []
        ),
    ])
    func enumerationSuggestions(partial: PartialFilterTerm, expected: [FilterQuery<FilterTerm>]) {
        let actual = Array(MagicCardSearch.enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "").prefix(100))
        let actualFilters = extractFilters(actual)
        #expect(actualFilters == expected)
        #expect(actual.allSatisfy { $0.source == .enumeration })
    }
}

// MARK: - filterTypeSuggestions

@Suite
struct FilterTypeSuggestionsTests {
    private func extractDisplayNames(_ suggestions: [AutocompleteSuggestion]) -> [String] {
        suggestions.compactMap {
            if case .filterType(let highlighted) = $0.content { highlighted.string } else { nil }
        }
    }

    @Test(
        "filterTypeSuggestions",
        arguments: [
            // prefix of a filter returns that filter first, followed by other substring matches
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("forma"))),
                ["format", "frame", "oracle", "oracletag", "watermark", "fulloracle"],
            ),
            // substrings matching multiple filters return them all by score
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("print"))),
                ["prints", "paperprints", "rarity", "restricted"],
            ),
            // exact match of an alias returns the alias before other matching filters
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("fo"))),
                ["fo", "format", "flavor", "function"],
            ),
            // unmatching string returns nothing
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("foobar"))),
                [],
            ),
            // negation is included in the result
            (
                PartialFilterTerm(polarity: .negative, content: .name(false, .bare("print"))),
                ["-prints", "-paperprints", "-rarity", "-restricted"],
            ),
            // case-insensitive (same results as the "forma" case)
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("ForMa"))),
                ["format", "frame", "oracle", "oracletag", "watermark", "fulloracle"],
            ),
            // prefixes are scored higher than other matches, then by length
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("or"))),
                [
                    "order",
                    "oracle",
                    "oracletag",
                    "color",
                    "border",
                    "format",
                    "flavor",
                    "keyword",
                    "fulloracle",
                    "power",
                ],
            ),
            // should prefer the shortest alias
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("ow"))),
                ["pow", "powtou"],
            ),
            // unquoted exact-match is not eligible
            (
                PartialFilterTerm(polarity: .positive, content: .name(true, .bare("form"))),
                [],
            ),
            // quoted exact-match is not eligible
            (
                PartialFilterTerm(polarity: .positive, content: .name(true, .balanced(.doubleQuote, "form"))),
                [],
            ),
            // quoted is not eligible because it implies a name search
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .unterminated(.doubleQuote, "form"))),
                [],
            ),
            // if operators are present we're past the point where we can suggest
            (
                PartialFilterTerm(polarity: .positive, content: .filter("form", .including, .bare(""))),
                [],
            ),
        ]
    )
    func filterTypeSuggestions(partial: PartialFilterTerm, expected: [String]) {
        let results = Array(MagicCardSearch.filterTypeSuggestions(for: partial, searchTerm: ""))
        let actualNames = extractDisplayNames(results)
        #expect(actualNames == expected, "\(actualNames) != \(expected)")
        #expect(results.allSatisfy { $0.source == .filterType })
    }
}

// MARK: - sortCombinedSuggestions

@Suite
struct SortCombinedSuggestionsTests {
    private func makeSuggestion(
        source: AutocompleteSuggestion.Source,
        filter: FilterQuery<FilterTerm>,
        score: Double
    ) -> AutocompleteSuggestion {
        let text = filter.description
        return AutocompleteSuggestion(
            source: source,
            content: .filter(WithHighlightedString(value: filter, string: text, searchTerm: "")),
            score: score
        )
    }

    @Test("sorts suggestions by biased score descending")
    func sortsByScore() {
        let low = makeSuggestion(source: .enumeration, filter: .term(.basic(.positive, "color", .equal, "red")), score: 0.8)
        let high = makeSuggestion(source: .enumeration, filter: .term(.basic(.positive, "color", .equal, "blue")), score: 0.95)
        let mid = makeSuggestion(source: .enumeration, filter: .term(.basic(.positive, "color", .equal, "green")), score: 0.9)

        let result = sortCombinedSuggestions([low, high, mid])
        #expect(result.map(\.score) == [0.95, 0.9, 0.8])
    }

    @Test("deduplicates by content, keeping the higher-scored copy")
    func deduplicatesByContent() {
        let filter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let lower = makeSuggestion(source: .enumeration, filter: filter, score: 0.8)
        let higher = makeSuggestion(source: .enumeration, filter: filter, score: 0.95)
        let other = makeSuggestion(source: .enumeration, filter: .term(.basic(.positive, "color", .equal, "blue")), score: 0.9)

        let result = sortCombinedSuggestions([lower, higher, other])
        #expect(result.count == 2)
        #expect(result[0].score == 0.95)
        #expect(result[1].score == 0.9)
    }

    @Test("pinned source bias lifts a lower-scored suggestion above a higher-scored one")
    func pinnedBiasLiftsScore() {
        let pinned = makeSuggestion(source: .pinnedFilter, filter: .term(.basic(.positive, "color", .equal, "red")), score: 0.85)
        let unpinned = makeSuggestion(source: .enumeration, filter: .term(.basic(.positive, "color", .equal, "blue")), score: 0.95)

        // pinned biasedScore = 0.85 + 1.0 = 1.85, unpinned = 0.95
        let result = sortCombinedSuggestions([unpinned, pinned])
        #expect(result.first?.source == .pinnedFilter)
    }

    @Test("history source bias lowers a higher-scored suggestion below a lower-scored one")
    func historyBiasLowersScore() {
        let history = makeSuggestion(source: .historyFilter, filter: .term(.basic(.positive, "color", .equal, "red")), score: 0.95)
        let other = makeSuggestion(source: .enumeration, filter: .term(.basic(.positive, "color", .equal, "blue")), score: 0.85)

        // history biasedScore = 0.95 - 1.0 = -0.05, other = 0.85
        let result = sortCombinedSuggestions([history, other])
        #expect(result.first?.source == .enumeration)
    }

    @Test("empty input returns empty output")
    func emptyInput() {
        #expect(sortCombinedSuggestions([]).isEmpty)
    }
}

// MARK: - nameSuggestions

@Suite
struct NameSuggestionsTests {
    struct TestCase: Sendable, CustomStringConvertible {
        let description: String
        let partial: PartialFilterTerm
        let mockResults: [String]
        let expectedFilters: [FilterQuery<FilterTerm>]

        init(_ description: String, _ partial: PartialFilterTerm, _ mockResults: [String], _ expectedFilters: [FilterQuery<FilterTerm>]) {
            self.description = description
            self.partial = partial
            self.mockResults = mockResults
            self.expectedFilters = expectedFilters
        }
    }

    private func extractFilters(_ suggestions: [AutocompleteSuggestion]) -> [FilterQuery<FilterTerm>] {
        suggestions.compactMap {
            if case .filter(let highlighted) = $0.content { highlighted.value } else { nil }
        }
    }

    @Test("nameSuggestions", arguments: [
        TestCase(
            "early-abort and return nothing if it looks like a non-name filter",
            PartialFilterTerm(polarity: .positive, content: .filter("foo", .including, .bare(""))),
            ["foobar"],
            []
        ),
        TestCase(
            "early-abort and return nothing if it's a name-type filter with less than 2 characters",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("f"))),
            ["foobar"],
            []
        ),
        TestCase(
            "return results if it's a name-type filter, adding quotes where necessary",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt", "Someone's Bolt"],
            [
                .term(.basic(.positive, "name", Comparison.including, "Lightning Bolt")),
                .term(.basic(.positive, "name", Comparison.including, "Someone's Bolt")),
                .term(.basic(.positive, "name", Comparison.including, "Firebolt")),
            ]
        ),
        TestCase(
            "is case-insensitive",
            PartialFilterTerm(polarity: .positive, content: .filter("nAmE", .including, .bare("boLT"))),
            ["Firebolt"],
            [.term(.basic(.positive, "name", Comparison.including, "Firebolt"))]
        ),
        TestCase(
            "respects the operator used",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .equal, .bare("bolt"))),
            ["Firebolt"],
            [.term(.basic(.positive, "name", Comparison.equal, "Firebolt"))]
        ),
        TestCase(
            "supports incomplete terms",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .equal, .unterminated(.singleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.basic(.positive, "name", Comparison.equal, "Lightning Bolt")),
                .term(.basic(.positive, "name", Comparison.equal, "Firebolt")),
            ]
        ),
        TestCase(
            "return results if it's quoted without a filter",
            PartialFilterTerm(polarity: .positive, content: .name(false, .unterminated(.doubleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.name(.positive, true, "Lightning Bolt")),
                .term(.name(.positive, true, "Firebolt")),
            ]
        ),
        TestCase(
            "return results if it's a literal name match",
            PartialFilterTerm(polarity: .positive, content: .name(true, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.name(.positive, true, "Lightning Bolt")),
                .term(.name(.positive, true, "Firebolt")),
            ]
        ),
        TestCase(
            "return results with negative polarity",
            PartialFilterTerm(polarity: .negative, content: .name(true, .unterminated(.doubleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.name(.negative, true, "Lightning Bolt")),
                .term(.name(.negative, true, "Firebolt")),
            ]
        ),
        TestCase(
            "only returns names that fuzzy-match the search term",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("foo"))),
            ["Wooded Foothills", "Shivan Reef"],
            [
                .term(.basic(.positive, "name", Comparison.including, "Wooded Foothills")),
            ]
        ),
        TestCase(
            "return matches even if it doesn't look like a filter",
            PartialFilterTerm(polarity: .positive, content: .name(false, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.name(.positive, true, "Lightning Bolt")),
                .term(.name(.positive, true, "Firebolt")),
            ]
        ),
    ])
    func nameSuggestions(testCase: TestCase) {
        let actual = Array(MagicCardSearch.nameSuggestions(for: testCase.partial, in: testCase.mockResults, searchTerm: ""))
        let actualFilters = extractFilters(actual)
        #expect(actualFilters == testCase.expectedFilters, "\(testCase.description)")
        #expect(actual.allSatisfy { $0.source == .name })
    }

    // TODO: Test limit parameter.
}
