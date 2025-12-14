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

    private var historyByFilter: [SearchFilter: HistoryEntry] = [:]
    private var sortedCache: [HistoryEntry]?

    private let hardLimit: Int
    private let softLimit: Int
    private let maxAgeInDays: Int
    private let persistenceKey = "filterHistory"

    // MARK: - Initialization

    init(hardLimit: Int = 1000, softLimit: Int = 500, maxAgeInDays: Int = 90) {
        self.hardLimit = hardLimit
        self.softLimit = softLimit
        self.maxAgeInDays = maxAgeInDays
        
        loadHistory()
        maybeGarbageCollectHistory()
    }

    private var sortedHistory: [HistoryEntry] {
        if let cached = sortedCache {
            return cached
        }

        let sorted = historyByFilter.values.sorted { lhs, rhs in
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

    func recordFilterUsage(_ filter: SearchFilter) {
        let wasPinned = historyByFilter[filter]?.isPinned ?? false

        let entry = HistoryEntry(
            filter: filter,
            lastUsedDate: Date(),
            isPinned: wasPinned
        )
        historyByFilter[filter] = entry

        maybeGarbageCollectHistory()
        invalidateCache()
        saveHistory()
    }

    func pinSearchFilter(_ filter: SearchFilter) {
        guard var entry = historyByFilter[filter] else { return }

        entry = HistoryEntry(
            filter: entry.filter,
            lastUsedDate: .now,
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
            lastUsedDate: .now,
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

    // MARK: - Garbage Collection

    private func maybeGarbageCollectHistory() {
        let originalCount = sortedHistory.count
        
        var reducedHistory = sortedHistory
        
        let cutoff = Date.now.addingTimeInterval(TimeInterval(-maxAgeInDays * 24 * 60 * 60))
        // n.b. assumes that sorted history puts pins at the beginning, which it does, but that
        // isn't encoded anywhere.
        if let i = reducedHistory.firstIndex(where: { !$0.isPinned && $0.lastUsedDate < cutoff }) {
            reducedHistory = Array(reducedHistory[..<i])
        }
    
        if reducedHistory.count > hardLimit {
            if let i = reducedHistory.firstIndex(where: { !$0.isPinned }) {
                reducedHistory = Array(reducedHistory[..<max(i, softLimit)])
            } else {
                reducedHistory = Array(reducedHistory[..<softLimit])
            }
        }
        
        if reducedHistory.count != originalCount {
            historyByFilter = reducedHistory.reduce(into: [:]) { dict, entry in
                dict[entry.filter] = entry
            }
            invalidateCache()
            saveHistory()
            
            print("Garbage collected \(reducedHistory.count - originalCount) history entries")
        }
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
