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
                    filterType: "manavalue",
                    comparison: .equal,
                    options: [.init(value: "even", range: nil), .init(value: "odd", range: nil)],
                ),
            ],
        ),
        (
            // narrows based on substring match, preferring shorter strings
            "is:scry",
            [
                .init(
                    filterType: "is",
                    comparison: .including,
                    options: [.init(value: "scryland", range: stringIndexRange(0, 4)), .init(value: "scryfallpreview", range: stringIndexRange(0, 4))],
                ),
            ],
        ),
        (
            // narrows with any substring, not just prefix, also, doesn't care about operator
            "format>=less",
            [
                .init(
                    filterType: "format",
                    comparison: .greaterThanOrEqual,
                    options: [.init(value: "timeless", range: stringIndexRange(4, 8))],
                ),
            ],
        ),
        (
            // the negation operator is preserved and does not affect behavior, but is included in the result
            "-is:scry",
            [
                .init(
                    filterType: "-is",
                    comparison: .including,
                    options: [.init(value: "scryland", range: stringIndexRange(0, 4)), .init(value: "scryfallpreview", range: stringIndexRange(0, 4))],
                ),
            ],
        ),
        (
            // case-insensitive
            "foRMat>=lESs",
            [
                .init(
                    filterType: "format",
                    comparison: .greaterThanOrEqual,
                    options: [.init(value: "timeless", range: stringIndexRange(4, 8))]
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
    func getSuggestions(input: String, expected: [EnumerationSuggestion]) async {
        #expect(await EnumerationSuggestionProvider().getSuggestions(input, existingFilters: [], limit: 1) == expected.map { .enumeration($0) })
    }
}
