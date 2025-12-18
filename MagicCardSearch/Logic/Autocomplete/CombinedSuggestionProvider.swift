//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

enum Suggestion: Equatable {
    case pinned(PinnedFilterSuggestion)
    case history(HistorySuggestion)
    case filter(FilterTypeSuggestion)
    case enumeration(EnumerationSuggestion)
    case name(NameSuggestion)
}

@MainActor
@Observable
class CombinedSuggestionProvider {
    let pinnedFilterProvider: PinnedFilterSuggestionProvider
    let historyProvider: HistorySuggestionProvider
    let filterTypeProvider: FilterTypeSuggestionProvider
    let enumerationProvider: EnumerationSuggestionProvider
    let nameProvider: NameSuggestionProvider
    
    let loadingState = DebouncedLoadingState()
    
    init(
        pinnedFilter: PinnedFilterSuggestionProvider,
        history: HistorySuggestionProvider,
        filterType: FilterTypeSuggestionProvider,
        enumeration: EnumerationSuggestionProvider,
        name: NameSuggestionProvider
    ) {
        self.pinnedFilterProvider = pinnedFilter
        self.historyProvider = history
        self.filterTypeProvider = filterType
        self.enumerationProvider = enumeration
        self.nameProvider = name
    }

    func getSuggestions(for searchTerm: String, existingFilters: Set<SearchFilter>) -> AsyncStream<[Suggestion]> {
        let currentTaskId = loadingState.start()
        
        return AsyncStream<[Suggestion]> { continuation in
            var allSuggestions: [Suggestion] = []
            
            let pinnedSuggestions = self.pinnedFilterProvider.getSuggestions(
                for: searchTerm,
                excluding: existingFilters,
            )
            allSuggestions.append(contentsOf: pinnedSuggestions.map { Suggestion.pinned($0) })
            
            let historySuggestions = self.historyProvider.getSuggestions(
                for: searchTerm,
                excluding: Set(pinnedSuggestions.map { $0.filter }).union(existingFilters),
                limit: 10
            )
            allSuggestions.append(contentsOf: historySuggestions.map { Suggestion.history($0) })
            
            let filterSuggestions = self.filterTypeProvider.getSuggestions(
                for: searchTerm,
                limit: 4
            )
            allSuggestions.append(contentsOf: filterSuggestions.map { Suggestion.filter($0) })
            
            let enumerationSuggestions = self.enumerationProvider.getSuggestions(
                for: searchTerm,
                limit: 1
            )
            allSuggestions.append(contentsOf: enumerationSuggestions.map { Suggestion.enumeration($0) })
            
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
                
                guard loadingState.isStillCurrent(id: currentTaskId), !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                
                allSuggestions.append(contentsOf: nameSuggestions.map { Suggestion.name($0) })
                
                continuation.yield(allSuggestions)
                
                loadingState.stop(for: currentTaskId)
                
                continuation.finish()
            }
        }
    }
}
