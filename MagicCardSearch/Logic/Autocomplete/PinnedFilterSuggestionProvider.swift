//
//  PinnedFilterAutocompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-18.
//

import Foundation
import Observation

struct PinnedFilterSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

class PinnedFilterSuggestionProvider {
    // MARK: - Properties
    
    private let store: PinnedFilterStore
    
    // MARK: - Initialization
    
    init(store: PinnedFilterStore) {
        self.store = store
    }
    
    // MARK: - Public Methods
    
    func getSuggestions(for partial: PartialSearchFilter, excluding excludedFilters: Set<SearchFilter>) -> [PinnedFilterSuggestion] {
        let searchTerm = partial.description.trimmingCharacters(in: .whitespaces)
        
        guard let pinnedRows = try? store.allPinnedFiltersChronologically else {
            return []
        }
        
        return pinnedRows
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
