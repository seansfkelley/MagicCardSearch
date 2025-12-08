//
//  FilterHistoryProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

@Observable
class FilterHistoryProvider {
    // MARK: - Properties
    
    private var history: [FilterHistoryEntry] = []
    private let maxHistoryCount = 1000
    private let persistenceKey = "filterHistory"
    
    // MARK: - Initialization
    
    init() {
        loadHistory()
    }
    
    // MARK: - Public Methods
    
    /// Records a filter in the history, updating its timestamp if it already exists
    func recordFilter(_ filter: SearchFilter) {
        let filterString = filter.toQueryStringWithEditingRange().0
        
        // Check if this filter already exists to preserve its pinned state
        let wasPinned = history.first(where: { $0.filterString == filterString })?.isPinned ?? false
        
        // Remove any existing entry with the same string representation
        history.removeAll { $0.filterString == filterString }
        
        // Add new entry at the beginning (most recent)
        let entry = FilterHistoryEntry(
            filterString: filterString,
            filter: filter,
            timestamp: Date(),
            isPinned: wasPinned
        )
        history.insert(entry, at: 0)
        
        // Trim to max count
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    /// Searches history for filters matching the given search term
    /// - Parameter prefix: The search term. If empty/whitespace, returns the 10 most recent entries.
    /// - Returns: Array of tuples containing the filter string and the range of the match (if any)
    func searchHistory(prefix: String) -> [(filterString: String, matchRange: Range<String.Index>?)] {
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespaces)
        
        // If empty, return 10 most recent with no match ranges
        if trimmedPrefix.isEmpty {
            let results = history.prefix(10).map { ($0.filterString, nil as Range<String.Index>?) }
            return sortByPinned(results)
        }
        
        // Search for entries that contain the search term anywhere, but exclude exact matches
        let matches = history.compactMap { entry -> (String, Range<String.Index>?)? in
            // Exclude exact matches (case-insensitive comparison)
            if entry.filterString.caseInsensitiveCompare(trimmedPrefix) == .orderedSame {
                return nil
            }
            
            if let range = entry.filterString.range(of: trimmedPrefix, options: .caseInsensitive) {
                return (entry.filterString, range)
            }
            return nil
        }
        
        return sortByPinned(matches)
    }
    
    /// Pins a filter to the top of search results
    /// - Parameter filterString: The string representation of the filter to pin
    func pinFilter(_ filterString: String) {
        if let index = history.firstIndex(where: { $0.filterString == filterString }) {
            history[index].isPinned = true
            saveHistory()
        }
    }
    
    /// Unpins a filter
    /// - Parameter filterString: The string representation of the filter to unpin
    func unpinFilter(_ filterString: String) {
        if let index = history.firstIndex(where: { $0.filterString == filterString }) {
            history[index].isPinned = false
            saveHistory()
        }
    }
    
    /// Checks if a filter is pinned
    /// - Parameter filterString: The string representation of the filter to check
    /// - Returns: Whether the filter is pinned
    func isPinned(_ filterString: String) -> Bool {
        history.first(where: { $0.filterString == filterString })?.isPinned ?? false
    }
    
    /// Toggles the pinned state of a filter
    /// - Parameter filterString: The string representation of the filter to toggle
    func togglePin(_ filterString: String) {
        if isPinned(filterString) {
            unpinFilter(filterString)
        } else {
            pinFilter(filterString)
        }
    }
    
    // MARK: - Private Helpers
    
    /// Sorts results by pinned status first, then by recency
    private func sortByPinned(_ results: [(filterString: String, matchRange: Range<String.Index>?)]) -> [(filterString: String, matchRange: Range<String.Index>?)] {
        return results.sorted { lhs, rhs in
            let lhsEntry = history.first(where: { $0.filterString == lhs.filterString })
            let rhsEntry = history.first(where: { $0.filterString == rhs.filterString })
            
            let lhsPinned = lhsEntry?.isPinned ?? false
            let rhsPinned = rhsEntry?.isPinned ?? false
            
            if lhsPinned != rhsPinned {
                // Pinned items come first
                return lhsPinned
            }
            
            // If both pinned or both unpinned, maintain original order (which is already by recency)
            // To maintain recency order, we need to find their indices
            guard let lhsIndex = history.firstIndex(where: { $0.filterString == lhs.filterString }),
                  let rhsIndex = history.firstIndex(where: { $0.filterString == rhs.filterString }) else {
                return false
            }
            
            return lhsIndex < rhsIndex
        }
    }
    
    /// Deletes a filter from the history by its string representation
    /// - Parameter filterString: The string representation of the filter to delete
    func deleteFilter(_ filterString: String) {
        history.removeAll { $0.filterString == filterString }
        saveHistory()
    }
    
    // MARK: - Persistence
    
    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(history)
            UserDefaults.standard.set(data, forKey: persistenceKey)
        } catch {
            print("Failed to save filter history: \(error)")
        }
    }
    
    private func loadHistory() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey) else {
            return
        }
        
        do {
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            history = try decoder.decode([FilterHistoryEntry].self, from: data)
        } catch {
            print("Failed to load filter history: \(error)")
            history = []
        }
    }
}

// MARK: - Filter History Entry

private struct FilterHistoryEntry: Codable {
    let filterString: String
    let filter: SearchFilter
    let timestamp: Date
    var isPinned: Bool
}
