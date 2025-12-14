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
            // return results with matching ranges if it's a name-type filter, adding quotes where necessary
            "name:bolt",
            ["Firebolt", "Lightning Bolt", "Someone's Bolt"],
            [("name:Firebolt", 9..<13), ("name:\"Lightning Bolt\"", 16..<20), ("name:\"Someone's Bolt\"", 16..<20)],
        ),
        (
            // is case-insensitive
            "nAmE:boLT",
            ["Firebolt"],
            [("name:Firebolt", 9..<13)],
        ),
        (
            // return results with matching ranges if it's a name-type filter, respecting the operator used
            "name=bolt",
            ["Firebolt"],
            [("name=Firebolt", 9..<13)],
        ),
        (
            // FIXME: Should this respect the users' input more closely and preserve quotes?
            // return results with matching ranges if it's a quoted name-type filter, using quotes only where necessary
            "name=\"bolt",
            ["Firebolt", "Lightning Bolt"],
            [("name=Firebolt", 9..<13), ("name=\"Lightning Bolt\"", 16..<20)],
        ),
        (
            // return results with matching ranges if it's quoted but without a filter, including quotes where appropriate
            "\"bolt",
            ["Firebolt", "Lightning Bolt"],
            [("Firebolt", 4..<8), ("\"Lightning Bolt\"", 11..<15)],
        ),
        (
            // return results with matching ranges if it's a literal name match, including quotes where appropriate
            "!bolt",
            ["Firebolt", "Lightning Bolt"],
            [("!Firebolt", 5..<9), ("!\"Lightning Bolt\"", 12..<16)],
        ),
        (
            // return results with matching ranges if it's a literal name match, including quotes where appropriate
            "-!\"bolt",
            ["Firebolt", "Lightning Bolt"],
            [("-!Firebolt", 6..<10), ("-!\"Lightning Bolt\"", 13..<17)],
        ),
        (
            // pass through all results from the matcher, even if we can't find the matching portion
            "name:foo",
            ["Wooded Foothills", "Shivan Reef"],
            [("name:\"Wooded Foothills\"", 13..<16), ("name:\"Shivan Reef\"", nil)],
        ),
    ])
    func getSuggestions(input: String, mockResults: [String], expected: [(String, Range<Int>?)]) async {
        let fetcher = MockCardNameFetcher(results: mockResults)
        
        let actual = await NameSuggestionProvider(fetcher: fetcher).getSuggestions(for: input, limit: Int.max)
        #expect(actual.map(\.filterText) == expected.map(\.0))
        #expect(
            actual.map(\.matchRange) == expected.map { $0.1.map(stringIndexRange) },
            "wanted highlights \(expected.map { mapHighlight($0.0, $0.1.map(stringIndexRange)) }) but would have gotten \(actual.map { mapHighlight($0.filterText, $0.matchRange) })"
        )
    }
    
    @Test<[(String, [String], [(String, Range<Int>?)])]>("permitBareSearchTerm", arguments: [
        (
            // return matches even if it doesn't look like a filter, including ! and quotes where necessary
            "bolt",
            ["Firebolt", "Lightning Bolt"],
            [("!Firebolt", 5..<9), ("!\"Lightning Bolt\"", 12..<16)],
        ),
        (
            // still recognizes filters if they are present and does not include them in the suggestions
            "name:bolt",
            ["Firebolt", "Lightning Bolt", "Someone's Bolt"],
            [("name:Firebolt", 9..<13), ("name:\"Lightning Bolt\"", 16..<20), ("name:\"Someone's Bolt\"", 16..<20)],
        ),
        (
            // still recognizes unambiguous name search operators if they are present and does not include them in the suggestions
            "!bolt",
            ["Firebolt", "Lightning Bolt"],
            [("!Firebolt", 5..<9), ("!\"Lightning Bolt\"", 12..<16)],
        ),
    ])
    func permitBareSearchTerm(input: String, mockResults: [String], expected: [(String, Range<Int>?)]) async {
        let fetcher = MockCardNameFetcher(results: mockResults)
        let actual = await NameSuggestionProvider(fetcher: fetcher).getSuggestions(
            for: input,
            limit: Int.max,
            permitBareSearchTerm: true
        )
        #expect(actual.map(\.filterText) == expected.map(\.0))
        #expect(
            actual.map(\.matchRange) == expected.map { $0.1.map(stringIndexRange) },
            "wanted highlights \(expected.map { mapHighlight($0.0, $0.1.map(stringIndexRange)) }) but would have gotten \(actual.map { mapHighlight($0.filterText, $0.matchRange) })"
        )
    }
    
    // TODO: Test limit parameter.
}

func mapHighlight(_ string: String, _ range: Range<String.Index>?) -> String? {
    range.map { String(string[$0]) }
}
