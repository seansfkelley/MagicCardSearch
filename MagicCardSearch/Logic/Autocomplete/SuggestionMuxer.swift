//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

@MainActor
@Observable
class SuggestionMuxer {
    let historyProvider: HistorySuggestionProvider
    let filterProvider: FilterTypeSuggestionProvider
    let enumerationProvider: EnumerationSuggestionProvider
    let nameProvider: NameSuggestionProvider
    
    var isLoading = false
    private var currentTask: Task<Void, Never>?
    
    init(
        historyProvider: HistorySuggestionProvider,
        filterProvider: FilterTypeSuggestionProvider,
        enumerationProvider: EnumerationSuggestionProvider,
        nameProvider: NameSuggestionProvider
    ) {
        self.historyProvider = historyProvider
        self.filterProvider = filterProvider
        self.enumerationProvider = enumerationProvider
        self.nameProvider = nameProvider
    }

    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter]) async -> [Suggestion] {
        // Cancel any previous request
        currentTask?.cancel()
        
        // Start loading
        isLoading = true
        
        var suggestions: [Suggestion] = []
        
        // Get all suggestions sequentially (they're fast except for name)
//        suggestions.append(contentsOf: await historyProvider.getSuggestions(searchTerm, existingFilters: existingFilters, limit: 10))
//        
//        guard !Task.isCancelled else { return [] }
        
        suggestions.append(contentsOf: await filterProvider.getSuggestions(searchTerm, existingFilters: existingFilters, limit: 4))
        
        guard !Task.isCancelled else { return [] }
        
        suggestions.append(contentsOf: await enumerationProvider.getSuggestions(searchTerm, existingFilters: existingFilters, limit: 1))
        
        guard !Task.isCancelled else { return [] }
        
        suggestions.append(contentsOf: await nameProvider.getSuggestions(searchTerm, existingFilters: existingFilters, limit: 10))
        
        isLoading = false
        
        return suggestions
    }
}
