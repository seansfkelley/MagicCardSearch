//
//  SearchState.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-31.
//
import SwiftUI
import Logging
import ScryfallKit
import SQLiteData

private let logger = Logger(label: "SearchState")

// TODO: Remove this decorator once I have disentagled a bunch of the state management.
@MainActor
@Observable
class SearchState {
    @ObservationIgnored @Dependency(\.defaultDatabase) var database

    public var searchText: String = ""
    public var searchSelection: TextSelection?
    public var filters: [SearchFilter] = []
    public private(set) var results: ScryfallObjectList<Card>?
    // TODO: This should eventually be private and only expose the suggestions themselves.
    public let suggestionProvider = CombinedSuggestionProvider(
        pinnedFilter: PinnedFilterSuggestionProvider(),
        history: HistorySuggestionProvider(),
        filterType: FilterTypeSuggestionProvider(),
        enumeration: EnumerationSuggestionProvider(),
        reverseEnumeration: ReverseEnumerationSuggestionProvider(),
        name: NameSuggestionProvider(debounce: .milliseconds(500))
    )

    public var selectedFilter: CurrentlyHighlightedFilterFacade {
        CurrentlyHighlightedFilterFacade(inputText: searchText, inputSelection: searchSelection)
    }

    private let scryfall = ScryfallClient(networkLogLevel: .minimal)

    public func clearAll() {
        searchText = ""
        searchSelection = nil
        filters = []
        results = nil
    }

    public func clearWarnings() {
        results?.clearWarnings()
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
            try database.write { db in
                try SearchHistoryEntry.insert { SearchHistoryEntry(filters: filters) }.execute(db)

                try FilterHistoryEntry.insert {
                    for filter in filters {
                        FilterHistoryEntry(filter: filter)
                    }
                }
                .execute(db)
            }
        } catch {
            logger.error("error while recording search", metadata: [
                "filters": "\(filters)",
                "error": "\(error)",
            ])
        }

        let query = filters.map { $0.description }.joined(separator: " ")
        results = .init { [weak self] page async throws in
            guard let self else { return .empty() }

            return try await scryfall.searchCards(
                query: query,
                unique: config.uniqueMode.toScryfallKitUniqueMode(),
                order: config.sortField.toScryfallKitSortMode(),
                sortDirection: config.sortOrder.toScryfallKitSortDirection(),
                page: page,
            )
        }

        _ = results!.loadNextPage()
    }
}
