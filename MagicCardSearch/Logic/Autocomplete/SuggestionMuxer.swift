//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

struct SuggestionMuxer: SuggestionProvider {
    let historyProvider: SuggestionProvider
    let filterProvider: SuggestionProvider
    let enumerationProvider: SuggestionProvider

    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter]) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        
        let historySuggestions = historyProvider.getSuggestions(searchTerm, existingFilters: existingFilters)
        suggestions.append(contentsOf: historySuggestions.prefix(5))
        
        let filterSuggestions = filterProvider.getSuggestions(searchTerm, existingFilters: existingFilters)
        suggestions.append(contentsOf: filterSuggestions.prefix(3))
        
        let enumerationSuggestions = enumerationProvider.getSuggestions(searchTerm, existingFilters: existingFilters)
        suggestions.append(contentsOf: enumerationSuggestions.prefix(1))
        
        return suggestions
    }
}
