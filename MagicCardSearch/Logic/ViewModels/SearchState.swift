import SwiftUI
import OSLog
import ScryfallKit

private let logger = Logger(subsystem: "MagicCardSearch", category: "SearchState")

@MainActor
@Observable
class SearchState {
    public private(set) var filters: [FilterQuery<FilterTerm>] = []
    public private(set) var configuration = SearchConfiguration.load()
    public private(set) var results: ScryfallObjectList<Card>?

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

    public func reset() {
        filters = []
        results = nil
    }

    public func search(
        withFilters newFilters: [FilterQuery<FilterTerm>]? = nil,
        withConfiguration newConfiguration: SearchConfiguration? = nil,
    ) {
        let oldFilters = filters
        let oldConfiguration = configuration

        filters = newFilters ?? filters
        configuration = newConfiguration ?? configuration

        guard filters != oldFilters || configuration != oldConfiguration else { return }

        // TODO: Move this into a didSet and/or make it more automatic.
        configuration.save()

        logger.info("starting new search filters=\(self.filters) configuration=\(self.configuration)")

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

        results!.loadNextPage()
    }
}
