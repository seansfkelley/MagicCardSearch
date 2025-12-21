//
//  NameSuggestionProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-13.
//

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
    struct TestCase {
        let description: String
        let input: String
        let mockResults: [String]
        let expected: [NameSuggestion]
        
        init(_ description: String, _ input: String, _ mockResults: [String], _ expected: [NameSuggestion]) {
            self.description = description
            self.input = input
            self.mockResults = mockResults
            self.expected = expected
        }
    }
    
    @Test("getSuggestions", arguments: [
        TestCase(
            "early-abort and return nothing if it looks like a non-name filter",
            "foo:",
            ["foobar"], // non-empty!
            []
        ),
        TestCase(
            "early-abort and return nothing if it's a name-type filter with less than 2 characters",
            "name:f",
            ["foobar"], // non-empty!
            []
        ),
        TestCase(
            "return results with matching ranges if it's a name-type filter, adding quotes where necessary",
            "name:bolt",
            ["Firebolt", "Lightning Bolt", "Someone's Bolt"],
            [
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.including, "Firebolt")),
                    matchRange: makeStringRange("name:Firebolt", 9..<13)
                ),
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.including, "Lightning Bolt")),
                    matchRange: makeStringRange("name:\"Lightning Bolt\"", 16..<20)
                ),
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.including, "Someone's Bolt")),
                    matchRange: makeStringRange("name:\"Someone's Bolt\"", 16..<20)
                ),
            ]
        ),
        TestCase(
            "is case-insensitive",
            "nAmE:boLT",
            ["Firebolt"],
            [
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.including, "Firebolt")),
                    matchRange: makeStringRange("name:Firebolt", 9..<13)
                ),
            ]
        ),
        TestCase(
            "return results with matching ranges if it's a name-type filter, respecting the operator used",
            "name=bolt",
            ["Firebolt"],
            [
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.equal, "Firebolt")),
                    matchRange: makeStringRange("name=Firebolt", 9..<13)
                ),
            ]
        ),
        TestCase(
            "supports incomplete terms, and does not respect choice of quote",
            "name='bolt",
            ["Firebolt", "Lightning Bolt"],
            [
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.equal, "Firebolt")),
                    matchRange: makeStringRange("name=Firebolt", 9..<13)
                ),
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.equal, "Lightning Bolt")),
                    matchRange: makeStringRange("name=\"Lightning Bolt\"", 16..<20)
                ),
            ]
        ),
        TestCase(
            "return results with matching ranges if it's quoted but without a filter, including quotes where appropriate",
            "\"bolt",
            ["Firebolt", "Lightning Bolt"],
            [
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.name("Firebolt", true)),
                    matchRange: makeStringRange("!Firebolt", 5..<9)
                ),
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.name("Lightning Bolt", true)),
                    matchRange: makeStringRange("!\"Lightning Bolt\"", 12..<16)
                ),
            ]
        ),
        TestCase(
            "return results with matching ranges if it's a literal name match, including quotes where appropriate",
            "!bolt",
            ["Firebolt", "Lightning Bolt"],
            [
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.name("Firebolt", true)),
                    matchRange: makeStringRange("!Firebolt", 5..<9)
                ),
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.name("Lightning Bolt", true)),
                    matchRange: makeStringRange("!\"Lightning Bolt\"", 12..<16)
                ),
            ]
        ),
        TestCase(
            "return results with matching ranges if it's a literal name match, including quotes where appropriate",
            "-!\"bolt",
            ["Firebolt", "Lightning Bolt"],
            [
                NameSuggestion(
                    filter: SearchFilter.negated(SearchFilterContent.name("Firebolt", true)),
                    matchRange: makeStringRange("-!Firebolt", 6..<10)
                ),
                NameSuggestion(
                    filter: SearchFilter.negated(SearchFilterContent.name("Lightning Bolt", true)),
                    matchRange: makeStringRange("-!\"Lightning Bolt\"", 13..<17)
                ),
            ]
        ),
        TestCase(
            "pass through all results from the matcher, even if we can't find the matching portion",
            "name:foo",
            ["Wooded Foothills", "Shivan Reef"],
            [
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.including, "Wooded Foothills")),
                    matchRange: makeStringRange("name:\"Wooded Foothills\"", 13..<16)
                ),
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.keyValue("name", Comparison.including, "Shivan Reef")),
                    matchRange: nil
                ),
            ]
        ),
        TestCase(
            "return matches even if it doesn't look like a filter, including ! and quotes where necessary",
            "bolt",
            ["Firebolt", "Lightning Bolt"],
            [
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.name("Firebolt", true)),
                    matchRange: makeStringRange("!Firebolt", 5..<9)
                ),
                NameSuggestion(
                    filter: SearchFilter.basic(SearchFilterContent.name("Lightning Bolt", true)),
                    matchRange: makeStringRange("!\"Lightning Bolt\"", 12..<16)
                ),
            ]
        ),
    ])
    func getSuggestions(testCase: TestCase) async {
        let fetcher = MockCardNameFetcher(results: testCase.mockResults)
        let actual = await NameSuggestionProvider(fetcher: fetcher).getSuggestions(for: testCase.input, limit: Int.max)
        #expect(actual == testCase.expected, "\(testCase.description)")
    }
    
    @Test("properly assigns match ranges when the search term overlaps with the 'name' filter")
    func getSuggestions() async {
        let fetcher = MockCardNameFetcher(results: ["Nameless Race"])
        let actual = await NameSuggestionProvider(fetcher: fetcher).getSuggestions(for: "name:name", limit: Int.max)
        withKnownIssue {
            #expect(actual == [
                NameSuggestion(
                    filter: .basic(.keyValue("name", .including, "Nameless Race")),
                    matchRange: makeStringRange("name:\"Nameless Race\"", 7..<11),
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
