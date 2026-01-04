import Foundation
import Observation
import SQLiteData

struct PinnedFilterSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

class PinnedFilterSuggestionProvider {
    // MARK: - Properties

    @ObservationIgnored @FetchAll private var pinnedFilters: [PinnedFilterEntry]

    // MARK: - Public Methods
    
    func getSuggestions(for partial: PartialSearchFilter, excluding excludedFilters: Set<SearchFilter>) -> [PinnedFilterSuggestion] {
        let searchTerm = partial.description.trimmingCharacters(in: .whitespaces)
        
        return pinnedFilters
            .filter { !excludedFilters.contains($0.filter) }
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
                
                if let range = filterText.range(of: searchTerm, options: .caseInsensitive) {
                    return PinnedFilterSuggestion(
                        filter: row.filter,
                        matchRange: range,
                        prefixKind: range.lowerBound == filterText.startIndex ? .actual : .none,
                        suggestionLength: filterText.count,
                    )
                }
                
                return nil
            }
    }
}
