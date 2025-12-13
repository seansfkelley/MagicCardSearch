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
    private var currentTaskID: UUID?
    
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
        
        // Create unique ID for this task
        let taskID = UUID()
        currentTaskID = taskID
        
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
        
        // Only turn off loading if we're still the current task
        if currentTaskID == taskID {
            isLoading = false
        }
        
        return suggestions
    }
}
