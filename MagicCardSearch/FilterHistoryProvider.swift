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
        let filterString = filter.toIdiomaticString()
        
        // Remove any existing entry with the same string representation
        history.removeAll { $0.filterString == filterString }
        
        // Add new entry at the beginning (most recent)
        let entry = FilterHistoryEntry(
            filterString: filterString,
            filter: filter,
            timestamp: Date()
        )
        history.insert(entry, at: 0)
        
        // Trim to max count
        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }
        
        saveHistory()
    }
    
    /// Searches history for filters matching the given prefix
    /// - Parameter prefix: The prefix to search for. If empty/whitespace, returns the 10 most recent entries.
    /// - Returns: Array of matching filter strings, ordered by recency
    func searchHistory(prefix: String) -> [String] {
        let trimmedPrefix = prefix.trimmingCharacters(in: .whitespaces)
        
        // If empty, return 10 most recent
        if trimmedPrefix.isEmpty {
            return Array(history.prefix(10).map { $0.filterString })
        }
        
        // Search for entries that begin with the prefix
        let matches = history.filter { entry in
            entry.filterString.hasPrefix(trimmedPrefix)
        }
        
        return matches.map { $0.filterString }
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
}
