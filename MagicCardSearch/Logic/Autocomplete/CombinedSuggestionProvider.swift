//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

enum Suggestion: Equatable {
    case history(HistorySuggestion)
    case filter(FilterTypeSuggestion)
    case enumeration(EnumerationSuggestion)
    case name(NameSuggestion)
}

@MainActor
@Observable
class CombinedSuggestionProvider {
    let historyProvider: HistorySuggestionProvider
    let filterProvider: FilterTypeSuggestionProvider
    let enumerationProvider: EnumerationSuggestionProvider
    let nameProvider: NameSuggestionProvider
    
    let loadingState = DebouncedLoadingState()
    
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

    func getSuggestions(for searchTerm: String, existingFilters: Set<SearchFilter>) -> AsyncStream<[Suggestion]> {
        let currentTaskId = loadingState.start()
        
        return AsyncStream<[Suggestion]> { continuation in
            var allSuggestions: [Suggestion] = []
            
            let historySuggestions = self.historyProvider.getSuggestions(
                for: searchTerm,
                excluding: existingFilters,
                limit: 10
            )
                .map { Suggestion.history($0) }
            allSuggestions.append(contentsOf: historySuggestions)
            
            let filterSuggestions = self.filterProvider.getSuggestions(
                for: searchTerm,
                limit: 4
            )
                .map { Suggestion.filter($0) }
            allSuggestions.append(contentsOf: filterSuggestions)
            
            let enumerationSuggestions = self.enumerationProvider.getSuggestions(
                for: searchTerm,
                limit: 1
            )
                .map { Suggestion.enumeration($0) }
            allSuggestions.append(contentsOf: enumerationSuggestions)
            
            continuation.yield(allSuggestions)
            
            guard loadingState.isStillCurrent(id: currentTaskId) else {
                continuation.finish()
                return
            }
                
            Task {
                let nameSuggestions = await self.nameProvider.getSuggestions(
                    for: searchTerm,
                    limit: 10,
                    permitBareSearchTerm: allSuggestions.isEmpty,
                )
                    .map { Suggestion.name($0) }
                
                guard loadingState.isStillCurrent(id: currentTaskId), !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                
                allSuggestions.append(contentsOf: nameSuggestions)
                
                continuation.yield(allSuggestions)
                
                loadingState.stop(for: currentTaskId)
                
                continuation.finish()
            }
        }
    }
}
