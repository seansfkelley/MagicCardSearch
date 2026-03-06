import Foundation
import Observation
import SQLiteData
import FuzzyMatch

struct PinnedFilterSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: FilterQuery<FilterTerm>
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

struct PinnedFilterSuggestionProvider {
    func getSuggestions(for partial: PartialFilterTerm, from pinnedFilters: [PinnedFilterEntry]) -> [PinnedFilterSuggestion] {
        let searchTerm = partial.description.trimmingCharacters(in: .whitespaces)

        let matcher = FuzzyMatcher()
        let query = matcher.prepare(searchTerm)
        var buffer = matcher.makeBuffer()

        return pinnedFilters
            .compactMap { row in
                let filterText = row.filter.description

                if searchTerm.isEmpty {
                    return PinnedFilterSuggestion(
                        filter: row.filter,
                        matchRange: nil,
                        // TODO: Would .actual produce better results?
                        prefixKind: .none,
                        suggestionLength: filterText.count,
                    )
                }

                if let match = matcher.score(filterText, against: query, buffer: &buffer) {
                    return PinnedFilterSuggestion(
                        filter: row.filter,
                        matchRange: nil,
                        prefixKind: .none,
                        suggestionLength: filterText.count,
                    )
                }
                
                return nil
            }
    }
}
