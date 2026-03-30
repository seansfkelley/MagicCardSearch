import SwiftUI
import OSLog
import ScryfallKit

private let logger = Logger(subsystem: "MagicCardSearch", category: "SearchState")

@MainActor
@Observable
class SearchState {
    public var filters: [FilterQuery<FilterTerm>] = [] {
        didSet {
            results = nil
        }
    }
    public var configuration = SearchConfiguration.load()
    public private(set) var results: ScryfallObjectList<Card>?
    public private(set) var searchNonce = 0

    private let suggestionProvider: AutocompleteSuggestionProvider
    private let scryfall = ScryfallClient(logger: logger)
    private let historyAndPinnedStore: HistoryAndPinnedStore

    public init(historyAndPinnedStore: HistoryAndPinnedStore, scryfallCatalogs: ScryfallCatalogs) {
        self.historyAndPinnedStore = historyAndPinnedStore
        self.suggestionProvider = AutocompleteSuggestionProvider(scryfallCatalogs: scryfallCatalogs)
    }

    public func makeEditingState() -> SearchEditingState {
        SearchEditingState(filters: filters, suggestionProvider: suggestionProvider)
    }

    public func clearAll() {
        filters = []
        results = nil
    }

    public func performSearch() {
        logger.info("starting new search filters=\(self.filters) configuration=\(self.configuration)")

        searchNonce += 1

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
                unique: configuration.uniqueMode.toScryfallKitUniqueMode(),
                order: configuration.sortField.toScryfallKitSortMode(),
                sortDirection: configuration.sortOrder.toScryfallKitSortDirection(),
                page: page,
            )
        }

        _ = results!.loadNextPage()
    }
}
