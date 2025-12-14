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
    
    var isLoading = false
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

    // swiftlint:disable:next function_body_length
    func getSuggestions(for searchTerm: String, existingFilters: Set<SearchFilter>) -> AsyncStream<[Suggestion]> {
        let taskID = UUID()
        currentTaskID = taskID
        
        isLoading = true
        
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
                
            Task {
                guard self.currentTaskID == taskID else {
                    await MainActor.run {
                        if self.currentTaskID == taskID {
                            self.isLoading = false
                        }
                    }
                    continuation.finish()
                    return
                }
                
                guard !Task.isCancelled else { return }
                
                let nameSuggestions = await self.nameProvider.getSuggestions(
                    for: searchTerm,
                    limit: 10,
                    permitBareSearchTerm: allSuggestions.isEmpty,
                )
                    .map { Suggestion.name($0) }
                
                guard self.currentTaskID == taskID, !Task.isCancelled else {
                    return
                }
                
                allSuggestions.append(contentsOf: nameSuggestions)
                
                continuation.yield(allSuggestions)
                
                await MainActor.run {
                    if self.currentTaskID == taskID {
                        self.isLoading = false
                    }
                }
                
                continuation.finish()
            }
        }
    }
    
    private func getPriority(for suggestion: Suggestion) -> Int {
        switch suggestion {
        case .history: return 0
        case .filter: return 1
        case .enumeration: return 2
        case .name: return 3
        }
    }
}
