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
    
    struct HistorySuggestion: Equatable {
        let filter: SearchFilter
        let isPinned: Bool
        let matchRange: Range<String.Index>?
    }
    
    struct FilterTypeSuggestion: Equatable {
        let filterType: String
        let matchRange: Range<String.Index>?
    }
    
    struct EnumerationSuggestion: Equatable {
        struct Option: Equatable {
            let value: String
            let range: Range<String.Index>?
        }
        
        let filterType: String
        let comparison: Comparison
        let options: [Option]
    }
    
    struct FilterTypeMatch {
        let canonicalType: String
        let displayText: String
        let range: Range<String.Index>
        let isExactMatch: Bool
        let matchLength: Int
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

    // TODO: yikes
    func suggestions(for searchTerm: String, excluding excludedFilters: Set<SearchFilter> = Set())
        -> [Suggestion] {
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

        results.append(contentsOf: AutocompleteProvider.getFilterTypeSuggestions(trimmedSearchTerm).map { .filter($0) })

        // Check for enumeration-type filter suggestions
        if let enumerationSuggestions = AutocompleteProvider.getEnumerationSuggestion(trimmedSearchTerm) {
            results.append(.enumeration(enumerationSuggestions))
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

    // TODO: yikes
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    internal static func getFilterTypeSuggestions(_ searchTerm: String) -> [FilterTypeSuggestion] {
        guard let match = try? /^(-?)([a-zA-Z]+)$/.wholeMatch(in: searchTerm) else {
            return []
        }
        
        var filterTypeMatches: [FilterTypeMatch] = []
        
        let (_, negated, filterName) = match.output
        
        for filterType in scryfallFilterTypes {
            var hasExactMatch = false
            var bestMatch: (text: String, range: Range<String.Index>, matchLength: Int)?
            
            for candidate in filterType.names {
                if candidate.caseInsensitiveCompare(filterName) == .orderedSame {
                    hasExactMatch = true
                    bestMatch = (
                        candidate, candidate.startIndex..<candidate.endIndex, candidate.count
                    )
                    break
                }

                if let range = candidate.range(of: filterName, options: .caseInsensitive) {
                    let matchLength = filterName.count

                    if let existing = bestMatch {
                        if matchLength > existing.matchLength
                            || (matchLength == existing.matchLength
                                && candidate == filterType.canonicalName)
                            || (matchLength == existing.matchLength
                                && existing.text != filterType.canonicalName
                                && candidate.count < existing.text.count) {
                            bestMatch = (candidate, range, matchLength)
                        }
                    } else {
                        bestMatch = (candidate, range, matchLength)
                    }
                }
            }

            if let (candidate, range, matchLength) = bestMatch {
                filterTypeMatches.append(FilterTypeMatch(
                    canonicalType: filterType.canonicalName,
                    displayText: candidate,
                    range: range,
                    isExactMatch: hasExactMatch,
                    matchLength: matchLength
                ))
            }
        }

        filterTypeMatches.sort { lhs, rhs in
            if lhs.isExactMatch != rhs.isExactMatch {
                return lhs.isExactMatch  // Exact matches first
            }
            if lhs.matchLength != rhs.matchLength {
                return lhs.matchLength > rhs.matchLength
            }
            if lhs.displayText == lhs.canonicalType && rhs.displayText != rhs.canonicalType {
                return true
            }
            if lhs.displayText != lhs.canonicalType && rhs.displayText == rhs.canonicalType {
                return false
            }
            return lhs.displayText.count < rhs.displayText.count
        }

        // TODO: Why does this seem to be sorting in reverse?
        return filterTypeMatches.reversed().map {
            let text = "\(negated)\($0.displayText)"
            return FilterTypeSuggestion(
                filterType: text,
                matchRange: negated.isEmpty ? $0.range : text.index(after: $0.range.lowerBound)..<text.index(after: $0.range.upperBound)
            )
        }
    }
    
    // TODO: yikes again
    internal static func getEnumerationSuggestion(_ searchTerm: String) -> EnumerationSuggestion? {
        // Some enumeration types, like rarity, are considered orderable, hence the comparison operators here.
        guard let match = try? /^(-?)([a-zA-Z]+)(:|=|!=|>=|>|<=|<)/.prefixMatch(in: searchTerm) else {
            return nil
        }
        
        let (_, negated, filterTypeName, comparisonOperator) = match.output
        let value = searchTerm[match.range.upperBound...]
        
        if let filterType = scryfallFilterByType[filterTypeName.lowercased()], let options = filterType.enumerationValues {
            var matchingOptions: [EnumerationSuggestion.Option] = []

            if value.isEmpty {
                matchingOptions = options.sorted().map { .init(value: $0, range: nil) }
            } else {
                var matches: [(option: String, range: Range<String.Index>)] = []

                for option in options {
                    if let range = option.range(of: value, options: .caseInsensitive) {
                        matches.append((option, range))
                    }
                }

                matches.sort { $0.option.count < $1.option.count }
                matchingOptions = matches.map { .init(value: $0.option, range: $0.range) }
            }

            if !matchingOptions.isEmpty {
                let comparison = Comparison(rawValue: String(comparisonOperator))
                assert(comparison != nil) // if it is, programmer error on the regex or enumeration type
                return EnumerationSuggestion(
                    filterType: "\(negated)\(filterTypeName)",
                    comparison: comparison!,
                    options: matchingOptions,
                )
            } else {
                return nil
            }
        } else {
            return nil
        }
    }

    private func sortResults(_ results: [Suggestion], historyLookup: [SearchFilter: HistoryEntry]) -> [Suggestion] {
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
