//
//  AutocompleteProviderTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-10.
//

import Testing
@testable import MagicCardSearch

struct AutocompleteProviderTests {
    @Test<[(String, AutocompleteProvider.EnumerationSuggestion)]>("getEnumerationSuggestions", arguments: [
        ("format=", .init(filterType: "format", comparison: .equal, options: [])),
    ])
    func getEnumerationSuggestions(input: String, expected: AutocompleteProvider.EnumerationSuggestion) {
        #expect(AutocompleteProvider.getEnumerationSuggestion(input) == expected)
    }
}
