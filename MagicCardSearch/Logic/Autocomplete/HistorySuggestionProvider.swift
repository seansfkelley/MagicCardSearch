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
    let isPinned: Bool
    let matchRange: Range<String.Index>?
}

@Observable
class HistorySuggestionProvider {
    // MARK: - Properties

    private let historyTracker: SearchHistoryTracker
    private var sortedCache: [HistoryEntry]?

    // MARK: - Initialization

    init(historyTracker: SearchHistoryTracker) {
        self.historyTracker = historyTracker
    }

    private var sortedHistory: [HistoryEntry] {
        if let cached = sortedCache {
            return cached
        }

        let sorted = historyTracker.historyByFilter.values.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }

            if lhs.lastUsedDate != rhs.lastUsedDate {
                return lhs.lastUsedDate > rhs.lastUsedDate
            }

            let lhsString = lhs.filter.queryStringWithEditingRange.0
            let rhsString = rhs.filter.queryStringWithEditingRange.0
            return lhsString.localizedCompare(rhsString) == .orderedAscending
        }

        sortedCache = sorted
        return sorted
    }

    private func invalidateCache() {
        sortedCache = nil
    }

    // MARK: - Public Methods

    func getSuggestions(for searchTerm: String, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [HistorySuggestion] {
        guard limit > 0 else {
            return []
        }
        
        let history = sortedHistory
        historyTracker.maybeGarbageCollectHistory(sortedHistory: history)
        
        // Invalidate cache if garbage collection may have modified history
        invalidateCache()
        
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)
        
        return Array(
            sortedHistory
                .lazy
                .filter { !excludedFilters.contains($0.filter) }
                .compactMap { entry in
                    if trimmedSearchTerm.isEmpty {
                        return HistorySuggestion(
                            filter: entry.filter,
                            isPinned: entry.isPinned,
                            matchRange: nil
                        )
                    }
                    
                    let filterString = entry.filter.queryStringWithEditingRange.0
                    if let range = filterString.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                        return HistorySuggestion(
                            filter: entry.filter,
                            isPinned: entry.isPinned,
                            matchRange: range,
                        )
                    }
                    
                    return nil
                }
                .prefix(limit)
        )
    }

    func pin(filter: SearchFilter) {
        historyTracker.updatePinStatus(for: filter, isPinned: true)
        invalidateCache()
    }

    func unpin(filter: SearchFilter) {
        historyTracker.updatePinStatus(for: filter, isPinned: false)
        invalidateCache()
    }

    func delete(filter: SearchFilter) {
        historyTracker.delete(filter: filter)
        invalidateCache()
    }
}
