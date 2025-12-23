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
                    isPrefix: false,
                    suggestionLength: 4
                ),
                .init(
                    filter: SearchFilter.basic(false, "manavalue", .equal, "odd"),
                    matchRange: nil,
                    isPrefix: false,
                    suggestionLength: 3
                ),
            ],
        ),
        (
            // narrows based on substring match, preferring strings earlier in the alphabet when
            // they are both prefixes
            PartialSearchFilter(negated: false, content: .filter("is", .including, .bare("scry"))),
            [
                .init(
                    filter: SearchFilter.basic(false, "is", .including, "scryfallpreview"),
                    matchRange: "is:scryfallpreview".range(of: "scry"),
                    isPrefix: true,
                    suggestionLength: 15
                ),
                .init(
                    filter: SearchFilter.basic(false, "is", .including, "scryland"),
                    matchRange: "is:scryland".range(of: "scry"),
                    isPrefix: true,
                    suggestionLength: 8
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
                    isPrefix: false,
                    suggestionLength: 8
                ),
            ],
        ),
        (
            // the negation operator is preserved and does not affect behavior, but is included in the result
            PartialSearchFilter(negated: true, content: .filter("is", .including, .bare("scry"))),
            [
                .init(
                    filter: SearchFilter.basic(true, "is", .including, "scryfallpreview"),
                    matchRange: "-is:scryfallpreview".range(of: "scry"),
                    isPrefix: true,
                    suggestionLength: 15
                ),
                .init(
                    filter: SearchFilter.basic(true, "is", .including, "scryland"),
                    matchRange: "-is:scryland".range(of: "scry"),
                    isPrefix: true,
                    suggestionLength: 8
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
                    isPrefix: false,
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
    @MainActor
    func getSuggestions(partial: PartialSearchFilter, expected: [EnumerationSuggestion]) {
        let actual = EnumerationSuggestionProvider().getSuggestions(for: partial, excluding: [], limit: 100)
        #expect(actual == expected)
    }
}
