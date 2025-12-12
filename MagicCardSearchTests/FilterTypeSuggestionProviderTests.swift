//
//  AutocompleteProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-10.
//

import Testing
@testable import MagicCardSearch

struct FilterTypeSuggestionProviderTests {
    @Test<[(String, [FilterTypeSuggestion])]>("getSuggestions", arguments: [
        (
            // prefix of a filter returns that filter
            "forma",
            [.init(filterType: "format", matchRange: stringIndexRange(0, 5))],
        ),
        (
            // substrings matching multiple filters return them all, shortest first
            "print",
            [
                .init(filterType: "prints", matchRange: stringIndexRange(0, 5)),
                .init(filterType: "paperprints", matchRange: stringIndexRange(5, 10)),
            ],
        ),
        (
            // exact match of an alias returns the alias before other matching filters, and does not return the canonical name
            "fo",
            [
                .init(filterType: "fo", matchRange: stringIndexRange(0, 2)),
                .init(filterType: "format", matchRange: stringIndexRange(0, 2)),
            ],
        ),
        (
            // unmatching string returns nothing
            "foobar",
            [],
        ),
        (
            // negation does not affect the behavior, but is included in the result
            // n.b. the index does not include the negation operator because it may not be contiguous
            "-print",
            [
                .init(filterType: "-prints", matchRange: stringIndexRange(1, 6)),
                .init(filterType: "-paperprints", matchRange: stringIndexRange(6, 11)),
            ],
        ),
        (
            // case-insensitive
            "ForMa",
            [.init(filterType: "format", matchRange: stringIndexRange(0, 5))],
        ),
        (
            // prefixes are scored higher than other matches, even if they're longer, then by length
            "or",
            [
                .init(filterType: "order", matchRange: stringIndexRange(0, 2)),
                .init(filterType: "oracle", matchRange: stringIndexRange(0, 2)),
                .init(filterType: "oracletag", matchRange: stringIndexRange(0, 2)),
                .init(filterType: "color", matchRange: stringIndexRange(3, 5)),
                .init(filterType: "format", matchRange: stringIndexRange(1, 3)),
                .init(filterType: "flavor", matchRange: stringIndexRange(4, 6)),
                .init(filterType: "border", matchRange: stringIndexRange(1, 3)),
                .init(filterType: "keyword", matchRange: stringIndexRange(4, 6)),
                .init(filterType: "fulloracle", matchRange: stringIndexRange(4, 6)),
            ],
        ),
        (
            // should prefer the shortest alias, skipping the canonical name, if neither is an exact match
            "ow",
            [
                .init(filterType: "pow", matchRange: stringIndexRange(1, 3)),
                .init(filterType: "powtou", matchRange: stringIndexRange(1, 3)),
            ]
        ),
    ]
)
    func getSuggestions(input: String, expected: [FilterTypeSuggestion]) {
        #expect(FilterTypeSuggestionProvider().getSuggestions(input, existingFilters: [], limit: Int.max) == expected.map { .filter($0) })
    }
}
