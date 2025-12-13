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
    @Test<[(String, [String], [(String, Range<Int>?)])]>("getSuggestions", arguments: [
        (
            // early-abort and return nothing if it doesn't look like a name filter
            "foo",
            ["foobar"], // non-empty!
            [],
        ),
        (
            // early-abort and return nothing if it's a name-type filter with less than 2 characters
            "name:f",
            ["foobar"], // non-empty!
            [],
        ),
        (
            // return results with matching ranges if it's a name-type filter
            "name:bolt",
            ["Firebolt"],
            [("name:Firebolt", 6..<13)],
        ),
//        (
//            // return results with matching ranges if it's a name-type filter
//            "name=bolt",
//        ),
//        (
//            // return results with matching ranges if it's a quoted name-type filter
//            "name=\"bolt",
//        ),
//        (
//            // return results with matching ranges if it's quoted but without a filter
//            "\"bolt",
//        ),
//        (
//            // return results with matching ranges if it's a literal name match, including quotes where appropriate
//            "!bolt",
//        ),
//        (
//            // return results with matching ranges if it's a literal name match, including quotes where appropriate
//            "-!\"bolt",
//        ),
//        (
//            // pass through all results from the matcher, even if we can't find the matching portion
//            "name:foo",
//        ),
//        (
//            
//        )
    ])
    func getSuggestions(input: String, mockResults: [String], expected: [(String, Range<Int>)]) async {
        let fetcher = MockCardNameFetcher(results: mockResults)
        let actual = await NameSuggestionProvider(fetcher: fetcher).getSuggestions(for: input, limit: Int.max)
        #expect(actual.map(\.filterText) == expected.map(\.0))
        #expect(
            actual.map(\.matchRange) == expected.map { stringIndexRange($0.1) },
            "wanted highlights \(expected.map { mapHighlight($0.0, stringIndexRange($0.1)) }) but would have gotten \(actual.map { mapHighlight($0.filterText, $0.matchRange) })"
        )
    }
}

func mapHighlight(_ string: String, _ range: Range<String.Index>?) -> String? {
    range.map { String(string[$0]) }
}
