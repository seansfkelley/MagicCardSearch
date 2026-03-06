import Foundation
import Observation
import SQLiteData
import FuzzyMatch

struct PinnedFilterSuggestionProvider {
    func getSuggestions(for partial: PartialFilterTerm, from pinnedFilters: [PinnedFilterEntry], searchTerm: String) -> [Suggestion] {
        let trimmedSearchTerm = partial.description.trimmingCharacters(in: .whitespaces)

        let matcher = FuzzyMatcher()
        let query = matcher.prepare(trimmedSearchTerm)
        var buffer = matcher.makeBuffer()

        return pinnedFilters
            .compactMap { row in
                let filterText = row.filter.description

                if trimmedSearchTerm.isEmpty {
                    return Suggestion(
                        source: .pinnedFilter,
                        content: .filter(WithHighlightedString(value: row.filter, string: filterText, searchTerm: searchTerm)),
                        score: 0,
                    )
                }

                if let match = matcher.score(filterText, against: query, buffer: &buffer) {
                    return Suggestion(
                        source: .pinnedFilter,
                        content: .filter(WithHighlightedString(value: row.filter, string: filterText, searchTerm: searchTerm)),
                        score: match.score,
                    )
                }

                return nil
            }
    }
}
