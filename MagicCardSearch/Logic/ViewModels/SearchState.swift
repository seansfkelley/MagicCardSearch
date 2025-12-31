//
//  SearchState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import Logging

private let logger = Logger(label: "SearchState")

// TODO: Remove this decorator once I have disentagled a bunch of the state management.
@MainActor
class SearchState {
    private let filterHistory: FilterHistoryStore
    private let searchHistory: SearchHistoryStore
    private let pinnedFilter: PinnedFilterStore

    private(set) var searchError: Error?

    // TODO: This should eventually be private and instead we expose the suggestions themselves.
    public var suggestionProvider: CombinedSuggestionProvider {
        CombinedSuggestionProvider(
            pinnedFilter: PinnedFilterSuggestionProvider(store: pinnedFilter),
            history: HistorySuggestionProvider(
                filterHistoryStore: filterHistory,
                searchHistoryStore: searchHistory,
            ),
            filterType: FilterTypeSuggestionProvider(),
            enumeration: EnumerationSuggestionProvider(),
            reverseEnumeration: ReverseEnumerationSuggestionProvider(),
            name: NameSuggestionProvider(debounce: .milliseconds(500))
        )
    }

    init(filterHistory: FilterHistoryStore, searchHistory: SearchHistoryStore, pinnedFilter: PinnedFilterStore) {
        self.filterHistory = filterHistory
        self.searchHistory = searchHistory
        self.pinnedFilter = pinnedFilter
    }
}
