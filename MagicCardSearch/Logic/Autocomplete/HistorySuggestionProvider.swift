//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation
import Observation

struct HistorySuggestion: Equatable, Sendable {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
}

@Observable
class HistorySuggestionProvider {
    // MARK: - Properties

    private let searchHistoryTracker: SearchHistoryTracker
    
    // MARK: - Initialization

    init(with tracker: SearchHistoryTracker) {
        self.searchHistoryTracker = tracker
    }

    // MARK: - Public Methods

    func getSuggestions(for searchTerm: String, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [HistorySuggestion] {
        guard limit > 0 else {
            return []
        }
        
        // TODO: Seems like someone else should be running this, not us.
        searchHistoryTracker.maybeGarbageCollectHistory()
        
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)
        
        return Array(
            searchHistoryTracker.sortedFilterHistory
                .lazy
                .filter { !excludedFilters.contains($0.filter) }
                .compactMap { entry in
                    if trimmedSearchTerm.isEmpty {
                        return HistorySuggestion(
                            filter: entry.filter,
                            matchRange: nil
                        )
                    }
                    
                    if let range = entry.filter.description.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                        return HistorySuggestion(
                            filter: entry.filter,
                            matchRange: range
                        )
                    }
                    
                    return nil
                }
                .prefix(limit)
        )
    }
}
