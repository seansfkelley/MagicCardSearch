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
    
    struct HistorySuggestion {
        let filter: SearchFilter
        let isPinned: Bool
        let matchRange: Range<String.Index>?
    }
    
    struct FilterTypeSuggestion {
        let filterType: String
        let matchRange: Range<String.Index>?
    }
    
    struct EnumerationSuggestion {
        let filterType: String
        let comparison: Comparison
        let options: [String: Range<String.Index>?]
    }
    
    enum Suggestion {
        case history(HistorySuggestion)
        case filter(FilterTypeSuggestion)
        case enumeration(EnumerationSuggestion)
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
                sortResults(availableHistory.map { 
                    Suggestion.history(HistorySuggestion(
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
            if let range = filterString.range(of: trimmedSearchTerm, options: .caseInsensitive) {
                results.append(.history(HistorySuggestion(
                    filter: entry.filter,
                    isPinned: entry.isPinned,
                    matchRange: range
                )))
            }
        }

        // Collect filter type matches with their match quality
        var filterTypeMatches:
            [(
                canonicalType: String,
                displayText: String,
                range: Range<String.Index>,
                isExactMatch: Bool,
                matchLength: Int
            )] = []

        for (canonicalFilterType, config) in filterFieldConfigurations {
            var filterTypeCandidates = [canonicalFilterType]
            filterTypeCandidates.append(contentsOf: config.aliases)

            var hasExactMatch = false
            var bestMatch: (text: String, range: Range<String.Index>, matchLength: Int)? = nil

            for candidate in filterTypeCandidates {
                // Check for exact match (case insensitive)
                if candidate.caseInsensitiveCompare(trimmedSearchTerm) == .orderedSame {
                    hasExactMatch = true
                    bestMatch = (
                        candidate, candidate.startIndex..<candidate.endIndex, candidate.count
                    )
                    break
                }

                // Check for partial match
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

            if let (candidate, range, matchLength) = bestMatch {
                filterTypeMatches.append(
                    (
                        canonicalType: canonicalFilterType,
                        displayText: candidate,
                        range: range,
                        isExactMatch: hasExactMatch,
                        matchLength: matchLength
                    )
                )
            }
        }

        // Sort filter type matches: exact matches first, then by descending match length
        filterTypeMatches.sort { lhs, rhs in
            if lhs.isExactMatch != rhs.isExactMatch {
                return lhs.isExactMatch  // Exact matches first
            }
            if lhs.matchLength != rhs.matchLength {
                return lhs.matchLength > rhs.matchLength  // Longer matches first (descending)
            }
            // Tie-breaker: prefer canonical names
            if lhs.displayText == lhs.canonicalType && rhs.displayText != rhs.canonicalType {
                return true
            }
            if lhs.displayText != lhs.canonicalType && rhs.displayText == rhs.canonicalType {
                return false
            }
            // Final tie-breaker: shorter text
            return lhs.displayText.count < rhs.displayText.count
        }

        // TODO: Why does this seem to be sorting in reverse?
        for match in filterTypeMatches.reversed() {
            results.append(.filter(FilterTypeSuggestion(
                filterType: match.displayText,
                matchRange: match.range
            )))
        }

        // Check for enumeration-type filter suggestions
        if let enumerationSuggestions = checkForEnumerationSuggestions(trimmedSearchTerm) {
            results.append(enumerationSuggestions)
        }

        let historyLookup = Dictionary(uniqueKeysWithValues: availableHistory.map { ($0.filter, $0) })
        return Array(sortResults(results, historyLookup: historyLookup).prefix(10))
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

    private func checkForEnumerationSuggestions(_ searchTerm: String) -> Suggestion? {
        for op in ["!=", ":", "="] {
            guard let operatorRange = searchTerm.range(of: op) else {
                continue
            }

            let filterPart = String(searchTerm[..<operatorRange.lowerBound])
            let valuePart = String(searchTerm[operatorRange.upperBound...])

            // Check if filterPart matches an enumeration filter
            if let config = configurationForKey(filterPart),
                case .enumeration(let options) = config.fieldType
            {

                // Filter and sort options based on valuePart
                var matchingOptions: [(option: String, range: Range<String.Index>?)] = []

                if valuePart.isEmpty {
                    // Return all options if no value part
                    matchingOptions = options.sorted { $0.count < $1.count }.map { ($0, nil) }
                } else {
                    // Find matching options
                    var matches: [(option: String, range: Range<String.Index>)] = []

                    for option in options {
                        if let range = option.range(of: valuePart, options: .caseInsensitive) {
                            matches.append((option, range))
                        }
                    }

                    // Sort by length (shortest first)
                    matches.sort { $0.option.count < $1.option.count }
                    matchingOptions = matches.map { ($0.option, $0.range as Range<String.Index>?) }
                }

                if !matchingOptions.isEmpty {
                    let comparison: Comparison
                    switch op {
                    case "=":
                        comparison = .equal
                    case "!=":
                        comparison = .notEqual
                    case ":":
                        comparison = .including
                    default:
                        comparison = .including
                    }
                    
                    return .enumeration(EnumerationSuggestion(
                        filterType: filterPart,
                        comparison: comparison,
                        options: Dictionary(uniqueKeysWithValues: matchingOptions.map { ($0.option, $0.range) })
                    ))
                }
            }

            // Once we find an operator, stop searching
            break
        }

        return nil
    }

    private func sortResults(_ results: [Suggestion], historyLookup: [SearchFilter: HistoryEntry]) -> [Suggestion] {
        return results.sorted { lhs, rhs in
            if case Suggestion.history(let lhHistory) = lhs,
                case Suggestion.history(let rhHistory) = rhs
            {
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
        history.removeAll(where: { $0.filter == filter })
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
