//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

struct SuggestionMuxer: SuggestionProvider {
    let providers: [SuggestionProvider]

    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter]) -> [Suggestion] {
        let suggestions: [Suggestion] = providers.flatMap { $0.getSuggestions(searchTerm, existingFilters: existingFilters) }
        return Array(suggestions.prefix(10))
    }
}
