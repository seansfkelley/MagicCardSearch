//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

struct HistorySuggestionProvider: SuggestionProvider {
    struct HistoryEntry: Codable {
        let filter: SearchFilter
        let timestamp: Date
        let isPinned: Bool
    }

    // MARK: - Properties

    private var history: [HistoryEntry] = []
    private let maxHistoryCount = 1000
    private let persistenceKey = "filterHistory"

    // MARK: - Initialization

    init() {
        loadHistory()
    }

    // MARK: - Public Methods
    
    func getSuggestions(_ searchTerm: String, excluding excludedFilters: [SearchFilter])
    -> [Suggestion] {
        let availableHistory = history.filter { !excludedFilters.contains($0.filter) }
        
        if searchTerm.isEmpty {
            return Array(
                sortResults(availableHistory.map {
                    .history(HistorySuggestion(
                        filter: $0.filter,
                        isPinned: $0.isPinned,
                        matchRange: nil
                    ))
                }, historyLookup: Dictionary(uniqueKeysWithValues: availableHistory.map { ($0.filter, $0) })).prefix(10)
            )
        }

        var results: [Suggestion] = []

        for entry in availableHistory {
            let filterString = entry.filter.queryStringWithEditingRange.0
            if let range = filterString.range(of: searchTerm, options: .caseInsensitive) {
                results.append(.history(HistorySuggestion(
                    filter: entry.filter,
                    isPinned: entry.isPinned,
                    matchRange: range
                )))
            }
        }

        let historyLookup = Dictionary(uniqueKeysWithValues: availableHistory.map { ($0.filter, $0) })
        return Array(sortResults(results, historyLookup: historyLookup).prefix(10))
    }

    // TODO: This implementation sucks.
    func recordFilterUsage(_ filter: SearchFilter) {
        let wasPinned = history.first { $0.filter == filter }?.isPinned ?? false

        history.removeAll { $0.filter == filter }

        let entry = HistoryEntry(
            filter: filter,
            timestamp: Date(),
            isPinned: wasPinned
        )
        history.insert(entry, at: 0)

        if history.count > maxHistoryCount {
            history = Array(history.prefix(maxHistoryCount))
        }

        saveHistory()
    }

    // TODO: Weird interface; improve it. Also, slow.
    func pinSearchFilter(_ filter: SearchFilter) {
        if let i = history.firstIndex(where: { $0.filter == filter }) {
            let entry = history[i]
            history[i] = HistoryEntry(
                filter: entry.filter,
                timestamp: entry.timestamp,
                isPinned: true
            )
            saveHistory()
        }
    }

    func unpinSearchFilter(_ filter: SearchFilter) {
        if let i = history.firstIndex(where: { $0.filter == filter }) {
            let entry = history[i]
            history[i] = HistoryEntry(
                filter: entry.filter,
                timestamp: entry.timestamp,
                isPinned: false
            )
            saveHistory()
        }
    }

    // MARK: - Private Helpers

    private func sortResults(_ results: [HistorySuggestion], historyLookup: [SearchFilter: HistoryEntry]) -> [HistorySuggestion] {
        return results.sorted { lhs, rhs in
            if case Suggestion.history(let lhHistory) = lhs,
                case Suggestion.history(let rhHistory) = rhs {
                if lhHistory.isPinned != rhHistory.isPinned {
                    return lhHistory.isPinned
                }

                // Look up timestamps from the history lookup
                let lhTimestamp = historyLookup[lhHistory.filter]?.timestamp ?? Date.distantPast
                let rhTimestamp = historyLookup[rhHistory.filter]?.timestamp ?? Date.distantPast
                return lhTimestamp > rhTimestamp
            } else if case Suggestion.history(_) = lhs {
                return true
            } else if case Suggestion.history(_) = rhs {
                return false
            } else {
                // TODO: Sort these for real.
                return true
            }
        }
    }

    func deleteSearchFilter(_ filter: SearchFilter) {
        history.removeAll { $0.filter == filter }
        saveHistory()
    }

    // MARK: - Persistence

    private func saveHistory() {
        do {
            // TODO: JSON seems like the wrong thing; isn't there a Swift-native encoding?
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
            history = try decoder.decode([HistoryEntry].self, from: data)
        } catch {
            print("Failed to load filter history: \(error)")
            history = []
        }
    }
}
