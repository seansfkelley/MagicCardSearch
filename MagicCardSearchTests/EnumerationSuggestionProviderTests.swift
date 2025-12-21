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
            PartialSearchFilter(negated: false, content: .filter("manavalue", .equal, .unquoted(""))),
            [
                .init(
                    filter: .basic(.keyValue("manavalue", .equal, "even")),
                    matchRange: nil
                ),
                .init(
                    filter: .basic(.keyValue("manavalue", .equal, "odd")),
                    matchRange: nil
                ),
            ],
        ),
        (
            // narrows based on substring match, preferring strings earlier in the alphabet when
            // they are both prefixes
            PartialSearchFilter(negated: false, content: .filter("is", .including, .unquoted("scry"))),
            [
                .init(
                    filter: .basic(.keyValue("is", .including, "scryfallpreview")),
                    matchRange: "is:scryfallpreview".range(of: "scry")
                ),
                .init(
                    filter: .basic(.keyValue("is", .including, "scryland")),
                    matchRange: "is:scryland".range(of: "scry")
                ),
            ],
        ),
        (
            // narrows with any substring, not just prefix, also, doesn't care about operator
            PartialSearchFilter(negated: false, content: .filter("format", .greaterThanOrEqual, .unquoted("less"))),
            [
                .init(
                    filter: .basic(.keyValue("format", .greaterThanOrEqual, "timeless")),
                    matchRange: "format>=timeless".range(of: "less")
                ),
            ],
        ),
        (
            // the negation operator is preserved and does not affect behavior, but is included in the result
            PartialSearchFilter(negated: true, content: .filter("is", .including, .unquoted("scry"))),
            [
                .init(
                    filter: .negated(.keyValue("is", .including, "scryfallpreview")),
                    matchRange: "-is:scryfallpreview".range(of: "scry")
                ),
                .init(
                    filter: .negated(.keyValue("is", .including, "scryland")),
                    matchRange: "-is:scryland".range(of: "scry")
                ),
            ],
        ),
        (
            // case-insensitive
            PartialSearchFilter(negated: false, content: .filter("foRMat", .greaterThanOrEqual, .unquoted("lESs"))),
            [
                .init(
                    filter: .basic(.keyValue("format", .greaterThanOrEqual, "timeless")),
                    matchRange: "format>=timeless".range(of: "less", options: .caseInsensitive)
                ),
            ],
        ),
        (
            // non-enumerable filter type yields no options
            PartialSearchFilter(negated: false, content: .filter("oracle", .equal, .unquoted(""))),
            [],
        ),
        (
            // incomplete filter types yield no suggestions
            PartialSearchFilter(negated: false, content: .name(false, .unquoted("form"))),
            [],
        ),
        (
            // unknown filter types yield no suggestions
            PartialSearchFilter(negated: false, content: .filter("foobar", .including, .unquoted(""))),
            [],
        ),
        (
            // incomplete operator is not completeable
            PartialSearchFilter(negated: false, content: .filter("format", .incompleteNotEqual, .unquoted(""))),
            [],
        ),
    ])
    @MainActor
    func getSuggestions(partial: PartialSearchFilter, expected: [EnumerationSuggestion]) {
        #expect(EnumerationSuggestionProvider().getSuggestions(for: partial, excluding: [], limit: 100) == expected)
    }
}
