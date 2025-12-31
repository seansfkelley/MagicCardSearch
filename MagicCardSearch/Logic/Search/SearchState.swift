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

    private(set) var searchError: Error?

    // TODO: This should eventually be private and instead we expose the suggestions themselves.
    public var suggestionProvider: CombinedSuggestionProvider {
        CombinedSuggestionProvider(
            pinnedFilter: PinnedFilterSuggestionProvider(),
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

    init(filterHistory: FilterHistoryStore, searchHistory: SearchHistoryStore) {
        self.filterHistory = filterHistory
        self.searchHistory = searchHistory
    }

    public func delete(filter: SearchFilter) {
        do {
            try filterHistory.deleteUsage(of: filter)
        } catch {
            logger.error("error while deleting filter", metadata: [
                "error": "\(error)",
            ])
            searchError = error
        }
    }

    public func unpin(filter: SearchFilter) {
        do {
            // Keep it around near the top since you just modified it.
            try filterHistory.recordUsage(of: filter)
        } catch {
            logger.error("error while unpinning filter", metadata: [
                "error": "\(error)",
            ])
            searchError = error
        }
    }

    public func getLatestSearches(count: Int) -> [SearchHistoryStore.Row] {
        do {
            // TODO: Does Swift get bitchy if this array isn't long enough?
            return try Array(searchHistory.allSearchesChronologically[...count])
        } catch {
            logger.error("error while retrieving latest searches", metadata: [
                "error": "\(error)",
            ])
            searchError = error
            return []
        }
    }
}
