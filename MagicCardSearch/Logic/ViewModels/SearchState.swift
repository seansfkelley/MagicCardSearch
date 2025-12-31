//
//  SearchState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import SwiftUI
import Logging
import ScryfallKit

private let logger = Logger(label: "SearchState")

// TODO: Remove this decorator once I have disentagled a bunch of the state management.
@MainActor
@Observable
class SearchState {
    public var searchText: String = ""
    public var searchSelection: TextSelection?
    public var filters: [SearchFilter] = []
    public private(set) var results: ScryfallObjectList<Card>?

    private let scryfall = ScryfallClient(networkLogLevel: .minimal)
    private let filterHistory: FilterHistoryStore
    private let searchHistory: SearchHistoryStore
    private let pinnedFilter: PinnedFilterStore

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

    public func clearAll() {
        searchText = ""
        searchSelection = nil
        filters = []
        results = nil
    }

    public func performSearch(withConfiguration config: SearchConfiguration) {
        logger.info("starting new search", metadata: [
            "filters": "\(filters)",
            "configuration": "\(config)",
        ])

        guard !filters.isEmpty else {
            logger.info("no search filters; skipping to empty result")
            results = .empty()
            return
        }

        do {
            try searchHistory.recordSearch(with: filters)
        } catch {
            logger.error("error while recording search", metadata: [
                "filters": "\(filters)",
                "error": "\(error)",
            ])
        }

        let query = filters.map { $0.description }.joined(separator: " ")
        results = .init() { [weak self] page async throws in
            guard let self else { return .empty() }

            return try await scryfall.searchCards(
                query: query,
                unique: config.uniqueMode.toScryfallKitUniqueMode(),
                order: config.sortField.toScryfallKitSortMode(),
                sortDirection: config.sortOrder.toScryfallKitSortDirection(),
                page: page,
            )
        }
    }
}
