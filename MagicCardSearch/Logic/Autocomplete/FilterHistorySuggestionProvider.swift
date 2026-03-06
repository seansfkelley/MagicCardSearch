import Foundation
import SQLiteData
import FuzzyMatch

struct FilterHistorySuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: FilterQuery<FilterTerm>
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

struct FilterHistorySuggestionProvider {
    func getSuggestions(for searchTerm: String, from filterHistoryEntries: [FilterHistoryEntry], limit: Int) -> [FilterHistorySuggestion] {
        guard limit > 0 else {
            return []
        }

        let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)

        let matcher = FuzzyMatcher()
        let query = matcher.prepare(trimmedSearchTerm)
        var buffer = matcher.makeBuffer()

        return Array(
            filterHistoryEntries
                .lazy
                .compactMap { entry in
                    let filterText = entry.filter.description

                    if trimmedSearchTerm.isEmpty {
                        return FilterHistorySuggestion(
                            filter: entry.filter,
                            matchRange: nil,
                            prefixKind: .none,
                            suggestionLength: filterText.count,
                        )
                    }

                    if let match = matcher.score(filterText, against: query, buffer: &buffer) {
                        return FilterHistorySuggestion(
                            filter: entry.filter,
                            matchRange: nil,
                            prefixKind: .none,
                            suggestionLength: filterText.count,
                        )
                    }

                    return nil
                }
                .prefix(limit)
        )
    }
}
