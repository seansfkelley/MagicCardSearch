import SwiftUI
import OSLog
import ScryfallKit

private let logger = Logger(subsystem: "MagicCardSearch", category: "SearchState")

private let includeExtrasFilter: FilterQuery<FilterTerm> = .term(.basic(.positive, "include", .including, "extras"))

@MainActor
@Observable
class SearchState {
    public private(set) var filters: [FilterQuery<FilterTerm>] = []
    public private(set) var configuration = SearchConfiguration.load() {
        didSet {
            configuration.save()
        }
    }
    public private(set) var results: ScryfallObjectList<Card>?
    public private(set) var didAutomaticallyIncludeExtras: Bool?

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
        didAutomaticallyIncludeExtras = nil
    }

    public func search(
        withFilters newFilters: [FilterQuery<FilterTerm>]? = nil,
        withConfiguration newConfiguration: SearchConfiguration? = nil,
    ) {
        var shouldSearch = false

        if let newFilters, newFilters != filters {
            filters = newFilters
            shouldSearch = true
        }

        if let newConfiguration, newConfiguration != configuration {
            configuration = newConfiguration
            shouldSearch = true
        }

        didAutomaticallyIncludeExtras = false

        guard shouldSearch else {
            logger.debug("early-aborting search because filters and configuration are the same")
            return
        }

        guard !filters.isEmpty else {
            logger.info("no search filters; skipping to empty result")
            results = .empty()
            return
        }

        historyAndPinnedStore.record(search: filters)

        doSearch(withFilters: filters, withConfiguration: configuration)
    }

    private func doSearch(
        withFilters instancedFilters: [FilterQuery<FilterTerm>],
        withConfiguration instancedConfiguration: SearchConfiguration,
    ) {
        logger.info("starting new search filters=\(instancedFilters) configuration=\(instancedConfiguration)")

        var mutableQuery = instancedFilters.map { $0.description }.joined(separator: " ")
        if let preferClause = instancedConfiguration.preferredPrint.toStringFilter() {
            // Scryfall will silently pick the last prefer: clause, so prepend it in case the user
            // has written one by hand in there somewhere.
            mutableQuery = "\(preferClause) \(mutableQuery)"
        }
        if let gameClause = instancedConfiguration.game.toStringFilter() {
            // TODO: Scryfall will AND this with any other hand-written game: clause, which is probably wrong.
            mutableQuery = "\(mutableQuery) \(gameClause)"
        }

        let query = mutableQuery // appease concurrency checker.

        let thisSearch = ScryfallObjectList<Card>({ [weak self] page async throws in
            guard let self else { return .empty() }

            return try await scryfall.searchCards(
                query: query,
                unique: instancedConfiguration.uniqueMode.toScryfallKitUniqueMode(),
                order: instancedConfiguration.sortField.toScryfallKitSortMode(),
                sortDirection: instancedConfiguration.sortOrder.toScryfallKitSortDirection(),
                page: page,
            )
        })

        results = thisSearch

        Task {
            await thisSearch.loadNextPage().value

            if (results === thisSearch
                && instancedConfiguration.automaticallyIncludeExtras
                && thisSearch.value.latestValue?.data.isEmpty ?? false)
                && !(didAutomaticallyIncludeExtras ?? true) // err on the side of not doing extra work
            {
                didAutomaticallyIncludeExtras = true
                doSearch(
                    withFilters: instancedFilters + [includeExtrasFilter],
                    withConfiguration: instancedConfiguration,
                )
            }
        }
    }
}
