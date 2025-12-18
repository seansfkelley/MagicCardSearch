//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation
import Observation

struct HistorySuggestion: Equatable {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
}

@Observable
class HistorySuggestionProvider {
    // MARK: - Properties

    private let historyTracker: SearchHistoryTracker
    
    // MARK: - Initialization

    init(historyTracker: SearchHistoryTracker) {
        self.historyTracker = historyTracker
    }

    // MARK: - Public Methods

    func getSuggestions(for searchTerm: String, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [HistorySuggestion] {
        guard limit > 0 else {
            return []
        }
        
        // TODO: Seems like someone else should be running this, not us.
        historyTracker.maybeGarbageCollectHistory()
        
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)
        
        return Array(
            historyTracker.sortedHistory
                .lazy
                .filter { !excludedFilters.contains($0.filter) }
                .compactMap { entry in
                    if trimmedSearchTerm.isEmpty {
                        return HistorySuggestion(
                            filter: entry.filter,
                            matchRange: nil
                        )
                    }
                    
                    let filterString = entry.filter.queryStringWithEditingRange.0
                    if let range = filterString.range(of: trimmedSearchTerm, options: .caseInsensitive) {
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
