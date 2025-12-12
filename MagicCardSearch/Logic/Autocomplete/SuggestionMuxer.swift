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

    // swiftlint:disable function_body_length
    /// Stream suggestions as they arrive from different providers
    /// Returns an AsyncStream that yields suggestion arrays as each provider completes
    func streamSuggestions(
        _ searchTerm: String,
        existingFilters: [SearchFilter]
    ) -> AsyncStream<[Suggestion]> {
        // Cancel any previous request
        currentTask?.cancel()
        
        // Capture provider values before entering the AsyncStream to avoid actor isolation issues
        let historyProvider = self.historyProvider
        let filterProvider = self.filterProvider
        let enumerationProvider = self.enumerationProvider
        let nameProvider = self.nameProvider
        
        return AsyncStream { continuation in
            let task = Task {
                var allSuggestions: [Suggestion] = []
                
                // Check for cancellation before starting
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                
                // First, get history suggestions (MainActor-isolated)
                // These are fast since they're in-memory
                let historySuggestions = await historyProvider.getSuggestions(
                    searchTerm,
                    existingFilters: existingFilters,
                    limit: 10
                )
                guard !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                allSuggestions.append(contentsOf: historySuggestions)
                continuation.yield(allSuggestions)
                
                // Run the remaining providers concurrently since they're Sendable structs
                await withTaskGroup(of: (priority: Int, suggestions: [Suggestion]).self) { group in
                    // Priority 1: Filter types (fast - local computation)
                    group.addTask {
                        let suggestions = await filterProvider.getSuggestions(
                            searchTerm,
                            existingFilters: existingFilters,
                            limit: 4
                        )
                        return (priority: 1, suggestions: suggestions)
                    }
                    
                    // Priority 2: Enumeration (fast - local computation)
                    group.addTask {
                        let suggestions = await enumerationProvider.getSuggestions(
                            searchTerm,
                            existingFilters: existingFilters,
                            limit: 1
                        )
                        return (priority: 2, suggestions: suggestions)
                    }
                    
                    // Priority 3: Name (may be slow due to network)
                    group.addTask {
                        let suggestions = await nameProvider.getSuggestions(
                            searchTerm,
                            existingFilters: existingFilters,
                            limit: 10
                        )
                        return (priority: 3, suggestions: suggestions)
                    }
                    
                    // Collect results as they arrive and yield incrementally
                    for await (priority, suggestions) in group {
                        // Check for cancellation
                        guard !Task.isCancelled else {
                            break
                        }
                        
                        // Insert suggestions at the appropriate position based on priority
                        // History (priority 0) is already at the start, so find where to insert
                        let historyCount = allSuggestions.prefix { suggestion in
                            getPriority(for: suggestion) == 0
                        }.count
                        
                        let insertionIndex = allSuggestions[historyCount...].firstIndex { suggestion in
                            getPriority(for: suggestion) > priority
                        } ?? allSuggestions.count
                        
                        allSuggestions.insert(contentsOf: suggestions, at: insertionIndex)
                        
                        // Yield the updated suggestions
                        continuation.yield(allSuggestions)
                    }
                }
                
                continuation.finish()
            }
            
            currentTask = task
            
            continuation.onTermination = { @Sendable _ in
                task.cancel()
            }
        }
    }
    // swiftlint:enable function_body_length
    
    /// Legacy method for backward compatibility
    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter]) async -> [Suggestion] {
        var finalSuggestions: [Suggestion] = []
        
        for await suggestions in streamSuggestions(searchTerm, existingFilters: existingFilters) {
            finalSuggestions = suggestions
        }
        
        return finalSuggestions
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
