//
//  EnumerationSuggestionProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//

import Testing
@testable import MagicCardSearch

struct EnumerationSuggestionProviderTests {
    @Test<[(PartialSearchFilter, [EnumerationSuggestion])]>("getSuggestions", arguments: [
        (
            // gives all values, in alphabetical order, if no value part is given
            PartialSearchFilter(negated: false, content: .filter("manavalue", .equal, .bare(""))),
            [
                .init(
                    filter: SearchFilter.basic(false, "manavalue", .equal, "even"),
                    matchRange: nil,
                    prefixKind: .none,
                    suggestionLength: 4
                ),
                .init(
                    filter: SearchFilter.basic(false, "manavalue", .equal, "odd"),
                    matchRange: nil,
                    prefixKind: .none,
                    suggestionLength: 3
                ),
            ],
        ),
        (
            // narrows based on substring match, preferring shorter strings when they are both prefixes
            PartialSearchFilter(negated: false, content: .filter("is", .including, .bare("scry"))),
            [
                .init(
                    filter: SearchFilter.basic(false, "is", .including, "scryland"),
                    matchRange: "is:scryland".range(of: "scry"),
                    prefixKind: .actual,
                    suggestionLength: 8
                ),
                .init(
                    filter: SearchFilter.basic(false, "is", .including, "scryfallpreview"),
                    matchRange: "is:scryfallpreview".range(of: "scry"),
                    prefixKind: .actual,
                    suggestionLength: 15
                ),
            ],
        ),
        (
            // narrows with any substring, not just prefix, also, doesn't care about operator
            PartialSearchFilter(negated: false, content: .filter("format", .greaterThanOrEqual, .bare("less"))),
            [
                .init(
                    filter: SearchFilter.basic(false, "format", .greaterThanOrEqual, "timeless"),
                    matchRange: "format>=timeless".range(of: "less"),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
            ],
        ),
        (
            // the negation operator is preserved and does not affect behavior, but is included in the result
            PartialSearchFilter(negated: true, content: .filter("is", .including, .bare("scry"))),
            [
                .init(
                    filter: SearchFilter.basic(true, "is", .including, "scryland"),
                    matchRange: "-is:scryland".range(of: "scry"),
                    prefixKind: .effective,
                    suggestionLength: 8
                ),
                .init(
                    filter: SearchFilter.basic(true, "is", .including, "scryfallpreview"),
                    matchRange: "-is:scryfallpreview".range(of: "scry"),
                    prefixKind: .effective,
                    suggestionLength: 15
                ),
            ],
        ),
        (
            // case-insensitive
            PartialSearchFilter(negated: false, content: .filter("foRMat", .greaterThanOrEqual, .bare("lESs"))),
            [
                .init(
                    filter: SearchFilter.basic(false, "format", .greaterThanOrEqual, "timeless"),
                    matchRange: "format>=timeless".range(of: "less", options: .caseInsensitive),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
            ],
        ),
        (
            // non-enumerable filter type yields no options
            PartialSearchFilter(negated: false, content: .filter("oracle", .equal, .bare(""))),
            [],
        ),
        (
            // incomplete filter types yield no suggestions
            PartialSearchFilter(negated: false, content: .name(false, .bare("form"))),
            [],
        ),
        (
            // unknown filter types yield no suggestions
            PartialSearchFilter(negated: false, content: .filter("foobar", .including, .bare(""))),
            [],
        ),
        (
            // incomplete operator is not completeable
            PartialSearchFilter(negated: false, content: .filter("format", .incompleteNotEqual, .bare(""))),
            [],
        ),
    ])
    func getSuggestions(partial: PartialSearchFilter, expected: [EnumerationSuggestion]) {
        let actual = EnumerationSuggestionProvider().getSuggestions(for: partial, excluding: [], limit: 100)
        #expect(actual == expected)
    }
}
