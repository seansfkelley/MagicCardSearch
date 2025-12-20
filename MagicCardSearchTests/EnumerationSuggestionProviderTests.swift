//
//  EnumerationSuggestionProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//

import Testing
@testable import MagicCardSearch

struct EnumerationSuggestionProviderTests {
    @Test<[(String, [EnumerationSuggestion])]>("getSuggestions", arguments: [
        (
            // gives all values, in alphabetical order, if no value part is given
            "manavalue=",
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
            "is:scry",
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
            "format>=less",
            [
                .init(
                    filter: .basic(.keyValue("format", .greaterThanOrEqual, "timeless")),
                    matchRange: "format>=timeless".range(of: "less")
                ),
            ],
        ),
        (
            // the negation operator is preserved and does not affect behavior, but is included in the result
            "-is:scry",
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
            "foRMat>=lESs",
            [
                .init(
                    filter: .basic(.keyValue("format", .greaterThanOrEqual, "timeless")),
                    matchRange: "format>=timeless".range(of: "less", options: .caseInsensitive)
                ),
            ],
        ),
        (
            // non-enumerable filter type yields no options
            "oracle=",
            [],
        ),
        (
            // incomplete filter types yield no suggestions
            "form",
            [],
        ),
        (
            // unknown filter types yield no suggestions
            "foobar:",
            [],
        ),
        (
            // incomplete operator is not completeable
            "format!",
            [],
        ),
    ])
    @MainActor
    func getSuggestions(input: String, expected: [EnumerationSuggestion]) {
        #expect(EnumerationSuggestionProvider().getSuggestions(for: input, excluding: [], limit: 100) == expected)
    }
}
