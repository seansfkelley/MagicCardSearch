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
            // non-enumerable yields no options
            "oracle=",
            nil
        ),
        (
            // incomplete operators yield no suggestions
            "form",
            nil,
        ),
        (
            // unknown operators yield no suggestions
            "foobar:",
            nil,
        ),
    ])
    func getEnumerationSuggestions(input: String, expected: AutocompleteProvider.EnumerationSuggestion?) {
        #expect(AutocompleteProvider.getEnumerationSuggestion(input) == expected)
    }
}
