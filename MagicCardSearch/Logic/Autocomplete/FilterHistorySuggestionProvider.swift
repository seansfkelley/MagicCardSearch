import Foundation
import SQLiteData
import FuzzyMatch

struct FilterHistorySuggestionProvider {
    func getSuggestions(for searchTerm: String, from filterHistoryEntries: [FilterHistoryEntry], limit: Int) -> [Suggestion] {
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
                        return Suggestion(
                            source: .historyFilter,
                            content: .filter(WithHighlightedString(value: entry.filter, string: filterText, searchTerm: searchTerm)),
                            score: 0,
                        )
                    }

                    if let match = matcher.score(filterText, against: query, buffer: &buffer) {
                        return Suggestion(
                            source: .historyFilter,
                            content: .filter(WithHighlightedString(value: entry.filter, string: filterText, searchTerm: searchTerm)),
                            score: match.score,
                        )
                    }

                    return nil
                }
                .prefix(limit)
        )
    }
}
