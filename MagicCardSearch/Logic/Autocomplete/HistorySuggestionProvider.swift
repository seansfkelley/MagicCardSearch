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
    
    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter])
    -> [Suggestion] {
        let availableHistory = history.filter { !existingFilters.contains($0.filter) }
        
        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)
        
        if trimmedSearchTerm.isEmpty {
            let historySuggestions = availableHistory.map {
                HistorySuggestion(
                    filter: $0.filter,
                    isPinned: $0.isPinned,
                    matchRange: nil
                )
            }
            let historyLookup = Dictionary(uniqueKeysWithValues: availableHistory.map { ($0.filter, $0) })
            return Array(sortResults(historySuggestions, historyLookup: historyLookup).prefix(10)).map { .history($0) }
        }

        var results: [HistorySuggestion] = []

        for entry in availableHistory {
            let filterString = entry.filter.queryStringWithEditingRange.0
            if let range = filterString.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                results.append(HistorySuggestion(
                    filter: entry.filter,
                    isPinned: entry.isPinned,
                    matchRange: range
                ))
            }
        }

        let historyLookup = Dictionary(uniqueKeysWithValues: availableHistory.map { ($0.filter, $0) })
        return Array(sortResults(results, historyLookup: historyLookup).prefix(10)).map { .history($0) }
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
                // Pinning means we like it, so boost its score by promoting it here.
                timestamp: Date(),
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
                // If we just unpinned it, it would be surprising for it to fall way down the
                // list if we last it a while ago. Consider it recently used, and it will naturally
                // age out as we don't use it.
                timestamp: Date(),
                isPinned: false
            )
            saveHistory()
        }
    }

    // MARK: - Private Helpers

    private func sortResults(_ results: [HistorySuggestion], historyLookup: [SearchFilter: HistoryEntry]) -> [HistorySuggestion] {
        return results.sorted { lhs, rhs in
            if lhs.isPinned != rhs.isPinned {
                return lhs.isPinned
            }

            // Look up timestamps from the history lookup
            let lhTimestamp = historyLookup[lhs.filter]?.timestamp ?? Date.distantPast
            let rhTimestamp = historyLookup[rhs.filter]?.timestamp ?? Date.distantPast
            return lhTimestamp > rhTimestamp
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
