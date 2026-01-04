import SwiftUI
import Logging
import ScryfallKit
import SQLiteData

private let logger = Logger(label: "SearchState")

// TODO: Remove this decorator once I have disentagled a bunch of the state management.
@MainActor
@Observable
class SearchState {
    public var searchText: String = ""
    public var searchSelection: TextSelection?
    public var filters: [SearchFilter] = []
    public private(set) var results: ScryfallObjectList<Card>?
    // TODO: This should eventually be private and only expose the suggestions themselves.
    public let suggestionProvider: CombinedSuggestionProvider

    public var selectedFilter: CurrentlyHighlightedFilterFacade {
        CurrentlyHighlightedFilterFacade(inputText: searchText, inputSelection: searchSelection)
    }

    private let scryfall = ScryfallClient(networkLogLevel: .minimal)
    private let historyAndPinnedStore: HistoryAndPinnedStore

    public init(historyAndPinnedStore: HistoryAndPinnedStore, scryfallCatalogs: ScryfallCatalogs) {
        self.historyAndPinnedStore = historyAndPinnedStore
        self.suggestionProvider = CombinedSuggestionProvider(
            pinnedFilter: PinnedFilterSuggestionProvider(),
            history: HistorySuggestionProvider(),
            filterType: FilterTypeSuggestionProvider(),
            enumeration: EnumerationSuggestionProvider(scryfallCatalogs: scryfallCatalogs),
            reverseEnumeration: ReverseEnumerationSuggestionProvider(scryfallCatalogs: scryfallCatalogs),
            name: NameSuggestionProvider(debounce: .milliseconds(500))
        )
    }

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

        historyAndPinnedStore.record(search: filters)

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
