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

/// Combined entry that merges history and pinned filter data
private struct CombinedEntry {
    let filter: SearchFilter
    let lastUsedDate: Date
    let isPinned: Bool
    let pinnedDate: Date?
}

@Observable
class HistorySuggestionProvider {
    // MARK: - Properties

    private let historyTracker: SearchHistoryTracker
    private let pinnedFilterProvider: PinnedFilterSuggestionProvider
    private var sortedCache: [CombinedEntry]?

    // MARK: - Initialization

    init(historyTracker: SearchHistoryTracker, pinnedFilterProvider: PinnedFilterSuggestionProvider) {
        self.historyTracker = historyTracker
        self.pinnedFilterProvider = pinnedFilterProvider
    }

    private var sortedHistory: [CombinedEntry] {
        if let cached = sortedCache {
            return cached
        }

        // Merge history and pinned filters
        var combinedByFilter: [SearchFilter: CombinedEntry] = [:]
        
        // Add all history entries
        for (filter, historyEntry) in historyTracker.historyByFilter {
            let pinnedEntry = pinnedFilterProvider.pinnedFiltersByFilter[filter]
            
            combinedByFilter[filter] = CombinedEntry(
                filter: filter,
                lastUsedDate: pinnedEntry?.lastUsedDate ?? historyEntry.lastUsedDate,
                isPinned: pinnedEntry != nil,
                pinnedDate: pinnedEntry?.pinnedDate
            )
        }
        
        // Add any pinned filters that aren't in history
        for (filter, pinnedEntry) in pinnedFilterProvider.pinnedFiltersByFilter {
            if combinedByFilter[filter] == nil {
                combinedByFilter[filter] = CombinedEntry(
                    filter: filter,
                    lastUsedDate: pinnedEntry.lastUsedDate,
                    isPinned: true,
                    pinnedDate: pinnedEntry.pinnedDate
                )
            }
        }

        let sorted = combinedByFilter.values.sorted { lhs, rhs in
            // Pinned items first
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }
            
            // Among pinned items, sort by pinned date (most recently pinned first)
            if lhs.isPinned, let lhsPinned = lhs.pinnedDate, let rhsPinned = rhs.pinnedDate {
                if lhsPinned != rhsPinned {
                    return lhsPinned > rhsPinned
                }
            }

            // Then by last used date
            if lhs.lastUsedDate != rhs.lastUsedDate {
                return lhs.lastUsedDate > rhs.lastUsedDate
            }

            // Finally alphabetically
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
        
        // Convert to HistoryEntry format for garbage collection
        let historyEntries = history.map { combined in
            HistoryEntry(
                filter: combined.filter,
                lastUsedDate: combined.lastUsedDate,
                isPinned: combined.isPinned
            )
        }
        historyTracker.maybeGarbageCollectHistory(sortedHistory: historyEntries)
        
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
                            matchRange: range
                        )
                    }
                    
                    return nil
                }
                .prefix(limit)
        )
    }

    func pin(filter: SearchFilter) {
        pinnedFilterProvider.pin(filter: filter)
        invalidateCache()
    }

    func unpin(filter: SearchFilter) {
        pinnedFilterProvider.unpin(filter: filter)
        invalidateCache()
    }

    func delete(filter: SearchFilter) {
        historyTracker.delete(filter: filter)
        pinnedFilterProvider.delete(filter: filter)
        invalidateCache()
    }
}
