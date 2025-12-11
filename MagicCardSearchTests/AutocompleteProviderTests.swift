//
//  AutocompleteProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-10.
//

import Testing
@testable import MagicCardSearch

func indexRange(_ from: Int, _ to: Int) -> Range<String.Index> {
    return
        String.Index.init(encodedOffset: from)
        ..<
        String.Index.init(encodedOffset: to)
}

struct AutocompleteProviderTests {
    @Test<[(String, AutocompleteProvider.EnumerationSuggestion?)]>("getEnumerationSuggestions", arguments: [
        (
            // gives all values, in alphabetical order, if no value part is given
            "manavalue=",
            .init(
                filterType: "manavalue",
                comparison: .equal,
                options: [.init(value: "even", range: nil), .init(value: "odd", range: nil)],
            )
        ),
        (
            // narrows based on substring match, preferring shorter strings
            "is:scry",
            .init(
                filterType: "is",
                comparison: .including,
                options: [.init(value: "scryland", range: indexRange(0, 4)), .init(value: "scryfallpreview", range: indexRange(0, 4))],
            )
        ),
        (
            // narrows with any substring, not just prefix, also, doesn't care about operator
            "format>=less",
            .init(filterType: "format", comparison: .greaterThanOrEqual, options: [.init(value: "timeless", range: indexRange(4, 8))])
        ),
        (
            // the negation operator is preserved and does not affect behavior, but is included in the result
            "-is:scry",
            .init(
                filterType: "-is",
                comparison: .including,
                options: [.init(value: "scryland", range: indexRange(0, 4)), .init(value: "scryfallpreview", range: indexRange(0, 4))],
            )
        ),
        (
            // case-insensitive
            "foRMat>=lESs",
            .init(filterType: "format", comparison: .greaterThanOrEqual, options: [.init(value: "timeless", range: indexRange(4, 8))])
        ),
        (
            // non-enumerable filter type yields no options
            "oracle=",
            nil
        ),
        (
            // incomplete filter types yield no suggestions
            "form",
            nil,
        ),
        (
            // unknown filter types yield no suggestions
            "foobar:",
            nil,
        ),
        (
            // incomplete operator is not completeable
            "format!",
            nil,
        ),
    ])
    func getEnumerationSuggestions(input: String, expected: AutocompleteProvider.EnumerationSuggestion?) {
        #expect(AutocompleteProvider.getEnumerationSuggestion(input) == expected)
    }
    
    @Test<[(String, [AutocompleteProvider.FilterTypeSuggestion])]>("getFilterTypeSuggestions", arguments: [
        (
            // prefix of a filter returns that filter
            "forma",
            [.init(filterType: "format", matchRange: indexRange(0, 5))],
        ),
        (
            // substrings matching multiple filters return them all, shortest first
            "print",
            [
                .init(filterType: "prints", matchRange: indexRange(0, 5)),
                .init(filterType: "paperprints", matchRange: indexRange(5, 10)),
            ],
        ),
        (
            // exact match of an alias returns the alias before other matching filters, and does not return the canonical name
            "fo",
            [
                .init(filterType: "fo", matchRange: indexRange(0, 2)),
                .init(filterType: "format", matchRange: indexRange(0, 2)),
            ],
        ),
        (
            // unmatching string returns nothing
            "foobar",
            [],
        ),
        (
            // negation does not affect the behavior, but is included in the result
            "-fo",
            [
                .init(filterType: "-fo", matchRange: indexRange(0, 3)),
                .init(filterType: "-format", matchRange: indexRange(0, 3)),
            ],
        ),
        (
            // case-insensitive
            "ForMa",
            [.init(filterType: "format", matchRange: indexRange(0, 5))],
        ),
    ]
)
    func getFilterTypeSuggestions(input: String, expected: [AutocompleteProvider.FilterTypeSuggestion]) {
        #expect(AutocompleteProvider.getFilterTypeSuggestions(input) == expected)
    }
}
