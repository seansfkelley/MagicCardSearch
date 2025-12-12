//
//  AutocompleteProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-10.
//

import Testing
@testable import MagicCardSearch

struct FilterTypeSuggestionProviderTests {
    @Test(
        "getSuggestions",
        arguments: [
            // prefix of a filter returns that filter
            (
                "forma",
                [("format", 0..<5)],
            ),
            // substrings matching multiple filters return them all, shortest first
            (
                "print",
                [("prints", 0..<5), ("paperprints", 5..<10)],
            ),
            // exact match of an alias returns the alias before other matching filters, and does not return the canonical name
            (
                "fo",
                [("fo", 0..<2), ("format", 0..<2)],
            ),
            // unmatching string returns nothing
            (
                "foobar",
                [],
            ),
            // negation does not affect the behavior, but is included in the result
            // n.b. the index does not include the negation operator because it may not be contiguous
            (
                "-print",
                [("-prints", 1..<6), ("-paperprints", 6..<11)],
            ),
            // case-insensitive
            (
                "ForMa",
                [("format", 0..<5)],
            ),
            // prefixes are scored higher than other matches, even if they're longer, then by length
            (
                "or",
                [
                    ("order", 0..<2),
                    ("oracle", 0..<2),
                    ("oracletag", 0..<2),
                    ("color", 3..<5),
                    ("format", 1..<3),
                    ("flavor", 4..<6),
                    ("border", 1..<3),
                    ("keyword", 4..<6),
                    ("fulloracle", 4..<6),
                ],
            ),
            // should prefer the shortest alias, skipping the canonical name, if neither is an exact match
            (
                "ow",
                [("pow", 1..<3), ("powtou", 1..<3)],
            ),
        ]
    )
    func getSuggestions(input: String, expected: [(String, Range<Int>)]) {
        let results = FilterTypeSuggestionProvider().getSuggestions(input, existingFilters: [], limit: Int.max)
        
        // TODO: Make this test body less horrible.
        
        let filterSuggestions = Array(results.compactMap { suggestion -> (String, Range<String.Index>)? in
            guard case .filter(let filterSuggestion) = suggestion else {
                return nil
            }
            return (filterSuggestion.filterType, filterSuggestion.matchRange)
        })
        
        #expect(
            filterSuggestions.elementsEqual(expected.map { ($0, stringIndexRange($1.lowerBound, $1.upperBound)) }) { $0 == $1 }
        )
    }
}
