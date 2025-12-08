//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

@Observable
class AutocompleteProvider {
    struct HistoryEntry: Codable {
        let filter: SearchFilter
        let timestamp: Date
        let isPinned: Bool
    }

    enum Suggestion {
        case history(HistoryEntry, Range<String.Index>?)
        case filterType(String, Range<String.Index>?)
        case comparison([Comparison: Range<String.Index>])
        case enumeration([(String, Range<String.Index>?)])
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

    // TODO: This implementation sucks.
    func recordFilterUsage(_ filter: SearchFilter) {
        let wasPinned = history.first(where: { $0.filter == filter })?.isPinned ?? false

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

    func suggestions(for searchTerm: String, excluding excludedFilters: Set<SearchFilter> = Set())
        -> [Suggestion]
    {
        let availableHistory = history.filter { !excludedFilters.contains($0.filter) }

        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)

        if trimmedSearchTerm.isEmpty {
            return Array(
                sortResults(availableHistory.map { Suggestion.history($0, nil) }).prefix(10)
            )
        }

        var results: [Suggestion] = []

        for entry in availableHistory {
            let filterString = entry.filter.queryStringWithEditingRange.0
            if let range = filterString.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                results.append(.history(entry, range))
            }
        }

        for (canonicalFilterType, config) in filterFieldConfigurations {
            var filterTypeCandidates = [canonicalFilterType]
            filterTypeCandidates.append(contentsOf: config.aliases)

            let hasExactMatch = filterTypeCandidates.contains { candidate in
                candidate.caseInsensitiveCompare(trimmedSearchTerm) == .orderedSame
            }

            if hasExactMatch {
                continue
            }

            var bestMatch: (text: String, range: Range<String.Index>, matchLength: Int)? = nil

            for candidate in filterTypeCandidates {
                if let range = candidate.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                    let matchLength = trimmedSearchTerm.count

                    if let existing = bestMatch {
                        if matchLength > existing.matchLength
                            || (matchLength == existing.matchLength
                                && candidate == canonicalFilterType)
                            || (matchLength == existing.matchLength
                                && existing.text != canonicalFilterType
                                && candidate.count < existing.text.count)
                        {
                            bestMatch = (candidate, range, matchLength)
                        }
                    } else {
                        bestMatch = (candidate, range, matchLength)
                    }
                }
            }

            if let (candidate, range, _) = bestMatch {
                results.append(.filterType(candidate, range))
            }
        }

        return Array(sortResults(results).prefix(10))
    }

    // TODO: Weird interface; improve it. Also, slow.
    func pinHistoryEntry(_ entry: HistoryEntry) {
        if let i = history.firstIndex(where: { $0.filter == entry.filter }) {
            history[i] = HistoryEntry(
                filter: entry.filter,
                timestamp: entry.timestamp,
                isPinned: true
            )
            saveHistory()
        }
    }

    func unpinHistoryEntry(_ entry: HistoryEntry) {
        if let i = history.firstIndex(where: { $0.filter == entry.filter }) {
            history[i] = HistoryEntry(
                filter: entry.filter,
                timestamp: entry.timestamp,
                isPinned: false
            )
            saveHistory()
        }
    }

    // MARK: - Private Helpers

    private func sortResults(_ results: [Suggestion]) -> [Suggestion] {
        return results.sorted { lhs, rhs in
            if case Suggestion.history(let lhHistory, _) = lhs,
                case Suggestion.history(let rhHistory, _) = rhs
            {
                if lhHistory.isPinned != rhHistory.isPinned {
                    return lhHistory.isPinned
                }

                return lhHistory.timestamp < rhHistory.timestamp
            } else if case Suggestion.history(_, _) = lhs {
                return true
            } else if case Suggestion.history(_, _) = rhs {
                return false
            } else {
                // TODO: Sort these for real.
                return true
            }
        }
    }

    func deleteHistoryEntry(_ entry: HistoryEntry) {
        history.removeAll(where: { $0.filter == entry.filter })
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
