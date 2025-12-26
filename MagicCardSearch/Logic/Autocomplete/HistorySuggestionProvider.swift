//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation
import Observation

struct HistorySuggestion: Equatable, Sendable, ScorableSuggestion {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
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
            searchHistoryTracker.sortedFilterEntries
                .lazy
                .filter { !excludedFilters.contains($0.filter) }
                .compactMap { entry in
                    let filterText = entry.filter.description

                    if trimmedSearchTerm.isEmpty {
                        return HistorySuggestion(
                            filter: entry.filter,
                            matchRange: nil,
                            // TODO: Would .actual produce better results?
                            prefixKind: .none,
                            suggestionLength: filterText.count,
                        )
                    }
                    
                    if let range = filterText.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                        return HistorySuggestion(
                            filter: entry.filter,
                            matchRange: range,
                            prefixKind: range.lowerBound == filterText.startIndex ? .actual : .none,
                            suggestionLength: filterText.count,
                        )
                    }
                    
                    return nil
                }
                .prefix(limit)
        )
    }
}
