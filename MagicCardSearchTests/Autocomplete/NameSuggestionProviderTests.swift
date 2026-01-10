import Testing
@testable import MagicCardSearch

// MARK: - Mock Fetcher

struct MockCardNameFetcher: CardNameFetcher {
    let results: [String]

    init(results: [String] = []) {
        self.results = results
    }

    func fetch(_ query: String) async -> [String] {
        return results
    }
}

// MARK: - Tests

struct NameSuggestionProviderTests {
    struct TestCase: Sendable, CustomStringConvertible {
        let description: String
        let partial: PartialFilterTerm
        let mockResults: [String]
        let expected: [NameSuggestion]

        init(_ description: String, _ partial: PartialFilterTerm, _ mockResults: [String], _ expected: [NameSuggestion]) {
            self.description = description
            self.partial = partial
            self.mockResults = mockResults
            self.expected = expected
        }
    }

    @Test("getSuggestions", arguments: [
        TestCase(
            "early-abort and return nothing if it looks like a non-name filter",
            PartialFilterTerm(polarity: .positive, content: .filter("foo", .including, .bare(""))),
            ["foobar"], // non-empty!
            []
        ),
        TestCase(
            "early-abort and return nothing if it's a name-type filter with less than 2 characters",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("f"))),
            ["foobar"], // non-empty!
            []
        ),
        TestCase(
            "return results with matching ranges if it's a name-type filter, adding quotes where necessary",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt", "Someone's Bolt"],
            [
                .init(
                    filter: .basic(.positive, "name", Comparison.including, "Firebolt"),
                    matchRange: makeStringRange("name:Firebolt", 9..<13),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
                .init(
                    filter: .basic(.positive, "name", Comparison.including, "Lightning Bolt"),
                    matchRange: makeStringRange("name:\"Lightning Bolt\"", 16..<20),
                    prefixKind: .none,
                    suggestionLength: 14
                ),
                .init(
                    filter: .basic(.positive, "name", Comparison.including, "Someone's Bolt"),
                    matchRange: makeStringRange("name:\"Someone's Bolt\"", 16..<20),
                    prefixKind: .none,
                    suggestionLength: 14
                ),
            ]
        ),
        TestCase(
            "is case-insensitive",
            PartialFilterTerm(polarity: .positive, content: .filter("nAmE", .including, .bare("boLT"))),
            ["Firebolt"],
            [
                .init(
                    filter: .basic(.positive, "name", Comparison.including, "Firebolt"),
                    matchRange: makeStringRange("name:Firebolt", 9..<13),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
            ]
        ),
        TestCase(
            "return results with matching ranges if it's a name-type filter, respecting the operator used",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .equal, .bare("bolt"))),
            ["Firebolt"],
            [
                .init(
                    filter: .basic(.positive, "name", Comparison.equal, "Firebolt"),
                    matchRange: makeStringRange("name=Firebolt", 9..<13),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
            ]
        ),
        TestCase(
            "supports incomplete terms, and does not respect choice of quote",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .equal, .unterminated(.singleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .init(
                    filter: .basic(.positive, "name", Comparison.equal, "Firebolt"),
                    matchRange: makeStringRange("name=Firebolt", 9..<13),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
                .init(
                    filter: .basic(.positive, "name", Comparison.equal, "Lightning Bolt"),
                    matchRange: makeStringRange("name=\"Lightning Bolt\"", 16..<20),
                    prefixKind: .none,
                    suggestionLength: 14
                ),
            ]
        ),
        TestCase(
            "return results with matching ranges if it's quoted but without a filter, including quotes where appropriate",
            PartialFilterTerm(polarity: .positive, content: .name(false, .unterminated(.doubleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .init(
                    filter: .name(.positive, true, "Firebolt"),
                    matchRange: makeStringRange("!Firebolt", 5..<9),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
                .init(
                    filter: .name(.positive, true, "Lightning Bolt"),
                    matchRange: makeStringRange("!\"Lightning Bolt\"", 12..<16),
                    prefixKind: .none,
                    suggestionLength: 14
                ),
            ]
        ),
        TestCase(
            "return results with matching ranges if it's a literal name match, including quotes where appropriate",
            PartialFilterTerm(polarity: .positive, content: .name(true, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .init(
                    filter: .name(.positive, true, "Firebolt"),
                    matchRange: makeStringRange("!Firebolt", 5..<9),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
                .init(
                    filter: .name(.positive, true, "Lightning Bolt"),
                    matchRange: makeStringRange("!\"Lightning Bolt\"", 12..<16),
                    prefixKind: .none,
                    suggestionLength: 14
                ),
            ]
        ),
        TestCase(
            "return results with matching ranges if it's a literal name match, including quotes where appropriate",
            PartialFilterTerm(polarity: .negative, content: .name(true, .unterminated(.doubleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .init(
                    filter: .name(.negative, true, "Firebolt"),
                    matchRange: makeStringRange("-!Firebolt", 6..<10),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
                .init(
                    filter: .name(.negative, true, "Lightning Bolt"),
                    matchRange: makeStringRange("-!\"Lightning Bolt\"", 13..<17),
                    prefixKind: .none,
                    suggestionLength: 14
                ),
            ]
        ),
        TestCase(
            "pass through all results from the matcher, even if we can't find the matching portion",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("foo"))),
            ["Wooded Foothills", "Shivan Reef"],
            [
                .init(
                    filter: .basic(.positive, "name", Comparison.including, "Wooded Foothills"),
                    matchRange: makeStringRange("name:\"Wooded Foothills\"", 13..<16),
                    prefixKind: .none,
                    suggestionLength: 16
                ),
                .init(
                    filter: .basic(.positive, "name", Comparison.including, "Shivan Reef"),
                    matchRange: nil,
                    prefixKind: .none,
                    suggestionLength: 11
                ),
            ]
        ),
        TestCase(
            "return matches even if it doesn't look like a filter, including ! and quotes where necessary",
            PartialFilterTerm(polarity: .positive, content: .name(false, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .init(
                    filter: .name(.positive, true, "Firebolt"),
                    matchRange: makeStringRange("!Firebolt", 5..<9),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
                .init(
                    filter: .name(.positive, true, "Lightning Bolt"),
                    matchRange: makeStringRange("!\"Lightning Bolt\"", 12..<16),
                    prefixKind: .none,
                    suggestionLength: 14
                ),
            ]
        ),
    ])
    func getSuggestions(testCase: TestCase) async {
        let fetcher = MockCardNameFetcher(results: testCase.mockResults)
        let actual = await NameSuggestionProvider(fetcher: fetcher).getSuggestions(for: testCase.partial, limit: Int.max)
        #expect(actual == testCase.expected, "\(testCase.description)")
    }

    @Test("properly assigns match ranges when the search term overlaps with the 'name' filter")
    func getSuggestions() async {
        let fetcher = MockCardNameFetcher(results: ["Nameless Race"])
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("name")))
        let actual = await NameSuggestionProvider(fetcher: fetcher).getSuggestions(for: partial, limit: Int.max)
        withKnownIssue {
            #expect(actual == [
                NameSuggestion(
                    filter: .basic(.positive, "name", .including, "Nameless Race"),
                    matchRange: makeStringRange("name:\"Nameless Race\"", 7..<11),
                    prefixKind: .effective,
                    suggestionLength: 13
                ),
            ])
        }
    }

    // TODO: Test limit parameter.
}

// Helper function to convert int ranges to String.Index ranges
func makeStringRange(_ string: String, _ range: Range<Int>?) -> Range<String.Index>? {
    guard let range = range else { return nil }
    let start = string.index(string.startIndex, offsetBy: range.lowerBound)
    let end = string.index(string.startIndex, offsetBy: range.upperBound)
    return start..<end
}
