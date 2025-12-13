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
    func getSuggestions(for searchTerm: String, existingFilters: [SearchFilter]) -> AsyncStream<[Suggestion]> {
        // Create unique ID for this request
        let taskID = UUID()
        currentTaskID = taskID
        
        // Start loading
        isLoading = true
        
        return AsyncStream<[Suggestion]> { continuation in
            Task {
                var allSuggestions: [Suggestion] = []
                
                // Run all providers concurrently using task group
                await withTaskGroup(of: (priority: Int, suggestions: [Suggestion]).self) { group in
                    // Priority 0: History (MainActor-isolated, but can still run in group)
//                    group.addTask { @MainActor in
//                        guard !Task.isCancelled else { return (priority: 0, suggestions: []) }
//                        let suggestions = await self.historyProvider.getSuggestions(
//                            searchTerm,
//                            existingFilters: existingFilters,
//                            limit: 10
//                        )
//                        return (priority: 0, suggestions: suggestions)
//                    }
                    
                    // Priority 1: Filter types (fast - local computation)
                    group.addTask {
                        guard !Task.isCancelled else { return (priority: 1, suggestions: []) }
                        let suggestions = self.filterProvider.getSuggestions(
                            for: searchTerm,
                            limit: 4
                        )
                            .map { Suggestion.filter($0) }
                        return (priority: 1, suggestions: suggestions)
                    }
                    
                    // Priority 2: Enumeration (fast - local computation)
                    group.addTask {
                        guard !Task.isCancelled else { return (priority: 2, suggestions: []) }
                        let suggestions = self.enumerationProvider.getSuggestions(
                            for: searchTerm,
                            limit: 1
                        )
                            .map { Suggestion.enumeration($0) }
                        return (priority: 2, suggestions: suggestions)
                    }
                    
                    // Priority 3: Name (may be slow due to network + debounce)
                    group.addTask {
                        guard !Task.isCancelled else { return (priority: 3, suggestions: []) }
                        let suggestions = await self.nameProvider.getSuggestions(
                            for: searchTerm,
                            limit: 10
                        )
                            .map { Suggestion.name($0) }
                        return (priority: 3, suggestions: suggestions)
                    }
                    
                    // Collect results as they arrive and yield incrementally
                    for await (priority, suggestions) in group {
                        // Check if this task is still current
                        guard await self.currentTaskID == taskID else {
                            // This task was superseded, stop yielding
                            break
                        }
                        
                        guard !Task.isCancelled else {
                            break
                        }
                        
                        // Insert suggestions at the appropriate position based on priority
                        let insertionIndex = allSuggestions.firstIndex { suggestion in
                            self.getPriority(for: suggestion) > priority
                        } ?? allSuggestions.count
                        
                        allSuggestions.insert(contentsOf: suggestions, at: insertionIndex)
                        
                        // Yield the updated suggestions
                        continuation.yield(allSuggestions)
                    }
                }
                
                // Only turn off loading if we're still the current task
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
