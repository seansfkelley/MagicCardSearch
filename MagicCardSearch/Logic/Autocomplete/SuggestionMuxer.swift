//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

struct SuggestionMuxer {
    let historyProvider: HistorySuggestionProvider
    let filterProvider: FilterTypeSuggestionProvider
    let enumerationProvider: EnumerationSuggestionProvider

    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter]) -> [Suggestion] {
        var suggestions: [Suggestion] = []
        
        let historySuggestions = historyProvider.getSuggestions(searchTerm, existingFilters: existingFilters, limit: 10)
        suggestions.append(contentsOf: historySuggestions)
        
        let filterSuggestions = filterProvider.getSuggestions(searchTerm, existingFilters: existingFilters, limit: 4)
        suggestions.append(contentsOf: filterSuggestions)
        
        let enumerationSuggestions = enumerationProvider.getSuggestions(searchTerm, existingFilters: existingFilters, limit: 1)
        suggestions.append(contentsOf: enumerationSuggestions)
        
        return suggestions
    }
}
