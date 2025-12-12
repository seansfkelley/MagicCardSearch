//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation
import Observation

@Observable
class HistorySuggestionProvider: SuggestionProvider {
    // MARK: - Properties

    private var historyByFilter: [SearchFilter: HistoryEntry] = [:]
    private var sortedCache: [HistoryEntry]?

    private let maxHistoryCount = 1000
    private let persistenceKey = "filterHistory"

    // MARK: - Initialization

    init() {
        loadHistory()
    }

    private var sortedHistory: [HistoryEntry] {
        if let cached = sortedCache {
            return cached
        }

        let sorted = historyByFilter.values.sorted { lhs, rhs in
            // Sort by: pinned, then last used date, then alphabetically
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

    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter], limit: Int) async -> [Suggestion] {
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)
        
        return Array(
            sortedHistory
                .lazy
                .filter { !existingFilters.contains($0.filter) }
                .compactMap { entry in
                    if trimmedSearchTerm.isEmpty {
                        return .history(
                            HistorySuggestion(
                                filter: entry.filter,
                                isPinned: entry.isPinned,
                                matchRange: nil
                            )
                        )
                    }
                    
                    let filterString = entry.filter.queryStringWithEditingRange.0
                    if let range = filterString.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                        return .history(
                            HistorySuggestion(
                                filter: entry.filter,
                                isPinned: entry.isPinned,
                                matchRange: range,
                            )
                        )
                    }
                    
                    return nil
                }
                .prefix(limit)
        )
    }

    func recordFilterUsage(_ filter: SearchFilter) {
        let wasPinned = historyByFilter[filter]?.isPinned ?? false

        let entry = HistoryEntry(
            filter: filter,
            lastUsedDate: Date(),
            isPinned: wasPinned
        )
        historyByFilter[filter] = entry

        // Enforce max count by removing oldest unpinned entries
        if historyByFilter.count > maxHistoryCount {
            let sortedByDate = historyByFilter.values
                .filter { !$0.isPinned }
                .sorted { $0.lastUsedDate < $1.lastUsedDate }

            let toRemove = sortedByDate.prefix(historyByFilter.count - maxHistoryCount)
            for entry in toRemove {
                historyByFilter.removeValue(forKey: entry.filter)
            }
        }

        invalidateCache()
        saveHistory()
    }

    func pinSearchFilter(_ filter: SearchFilter) {
        guard var entry = historyByFilter[filter] else { return }

        entry = HistoryEntry(
            filter: entry.filter,
            lastUsedDate: entry.lastUsedDate,
            isPinned: true
        )
        historyByFilter[filter] = entry
        invalidateCache()
        saveHistory()
    }

    func unpinSearchFilter(_ filter: SearchFilter) {
        guard var entry = historyByFilter[filter] else { return }

        entry = HistoryEntry(
            filter: entry.filter,
            lastUsedDate: entry.lastUsedDate,
            isPinned: false
        )
        historyByFilter[filter] = entry
        invalidateCache()
        saveHistory()
    }

    func deleteSearchFilter(_ filter: SearchFilter) {
        historyByFilter.removeValue(forKey: filter)
        invalidateCache()
        saveHistory()
    }

    // MARK: - Persistence

    private func saveHistory() {
        do {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            let data = try encoder.encode(historyByFilter)
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
            historyByFilter = try decoder.decode([SearchFilter: HistoryEntry].self, from: data)
        } catch {
            print("Failed to load filter history: \(error)")
            historyByFilter = [:]
        }
    }
}

struct HistoryEntry: Codable {
    let filter: SearchFilter
    let lastUsedDate: Date
    let isPinned: Bool
}
