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
    public private(set) var effectiveSortField: SearchConfiguration.SortField = SearchConfiguration.load().sortField
    public private(set) var results: ScryfallObjectList<Card>?
    public private(set) var didAutomaticallyIncludeExtras: Bool?

    private let suggestionProvider: AutocompleteSuggestionProvider
    private let cardSearchService: CardSearchService
    private let namedCardService: NamedCardService
    private let historyAndPinnedStore: HistoryAndPinnedStore

    public init(
        historyAndPinnedStore: HistoryAndPinnedStore,
        scryfallCatalogs: ScryfallCatalogs,
        cardSearchService: CardSearchService? = nil,
        namedCardService: NamedCardService? = nil,
    ) {
        self.historyAndPinnedStore = historyAndPinnedStore
        self.suggestionProvider = AutocompleteSuggestionProvider(scryfallCatalogs: scryfallCatalogs)
        self.cardSearchService = cardSearchService ?? CachingScryfallService.shared
        self.namedCardService = namedCardService ?? CachingScryfallService.shared
    }

    public func makeEditingState() -> SearchEditingState {
        SearchEditingState(filters: filters, suggestionProvider: suggestionProvider)
    }

    public func reset() {
        filters = []
        results = nil
        didAutomaticallyIncludeExtras = nil
        effectiveSortField = configuration.sortField
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
            logger.debug("early-aborting search because filters and configuration did not change")
            return
        }

        effectiveSortField = filters.flatMap(\.orderTermValues).last
            .flatMap(SearchConfiguration.SortField.fromApiValue) ?? configuration.sortField

        guard !filters.isEmpty else {
            logger.info("no search filters; skipping to empty result")
            results = .empty()
            return
        }

        historyAndPinnedStore.record(search: filters)

        doSearch(withFilters: filters, withConfiguration: configuration)
    }

    public func retry() {
        didAutomaticallyIncludeExtras = false

        effectiveSortField = filters.flatMap(\.orderTermValues).last
            .flatMap(SearchConfiguration.SortField.fromApiValue) ?? configuration.sortField

        guard !filters.isEmpty else {
            logger.info("no search filters; skipping to empty result")
            results = .empty()
            return
        }

        doSearch(withFilters: filters, withConfiguration: configuration)
    }

    private func doSearch(
        withFilters instancedFilters: [FilterQuery<FilterTerm>],
        withConfiguration instancedConfiguration: SearchConfiguration,
    ) {
        results?.destroy()

        logger.info("starting new search filters=\(instancedFilters) configuration=\(instancedConfiguration)")

        let preferredPrintFilter = instancedConfiguration.preferredPrint.toFilterTerm()

        if instancedFilters.count == 1,
            let filter = instancedFilters.first,
            case .term(let term) = filter,
            case .name(let polarity, let isExact, let name) = term,
           polarity == .positive && isExact,
           preferredPrintFilter == nil
        {
            logger.info("filters are a single positive exact name match; using fast path for finding name=\(name)")
            results = ScryfallObjectList<Card>({ @MainActor [weak self] page async throws in
                guard let self else { return .empty() }

                do {
                    let card = try await namedCardService.fetchCard(byExactName: name, set: nil)
                    return ObjectList(data: [card], hasMore: false, totalCards: 1)
                } catch let error as ScryfallKitError {
                    try Task.checkCancellation()

                    // When searching for cards, a 404 means "no results found", not an actual error.
                    // Note that this condition assumes that we will never get legit 404s. This should
                    // be fine since we only use a small number of fixed URLs, but of course it's not
                    // foolproof if Scryfall makes breaking changes.
                    if case .scryfallError(let scryfallError) = error, scryfallError.status == 404 {
                        logger.debug("intercepted Scryfall 404 and set to empty instead")
                        return .empty()
                    } else {
                        logger.error("failed to load card with name=\(name) error=\(error)")
                        throw error
                    }
                }
            })
            results!.loadNextPage()

            return
        }

        // Scryfall will silently pick the last prefer: clause, so prepend it in case the user
        // has written one by hand in there somewhere.
        let filters = if let preferredPrintFilter {
            [.term(preferredPrintFilter)] + instancedFilters
        } else {
            instancedFilters
        }

        let thisResults = ScryfallObjectList<Card>({ @MainActor [weak self] page async throws in
            guard let self else { return .empty() }

            return try await cardSearchService.searchCards(
                filters: filters,
                unique: instancedConfiguration.uniqueMode.toScryfallKitUniqueMode(),
                order: instancedConfiguration.sortField.toScryfallKitSortMode(),
                sortDirection: instancedConfiguration.sortOrder.toScryfallKitSortDirection(),
                page: page,
            )
        })
        results = thisResults

        Task {
            do {
                try await thisResults.loadNextPage().value
            } catch {
                // Swallow the error; the logger in ScryfallObjectList will log it.
                return
            }

            if case .loaded = thisResults.value,
               // The === check is belt-and-suspenders for cancellation, which should hit the early
               // return in the catch block immediately above.
               (results === thisResults
                && instancedConfiguration.automaticallyIncludeExtras
                && thisResults.value.latestValue?.data.isEmpty ?? false)
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

private extension FilterQuery where Term == FilterTerm {
    var orderTermValues: [String] {
        switch self {
        case .term(let term):
            if case .basic(_, "order", .including, let value) = term { return [value] }
            return []
        case .and(_, let children), .or(_, let children):
            return children.flatMap(\.orderTermValues)
        }
    }
}
