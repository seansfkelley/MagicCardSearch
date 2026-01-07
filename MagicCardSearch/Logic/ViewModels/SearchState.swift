import SwiftUI
import Logging
import ScryfallKit

private let logger = Logger(label: "SearchState")

// TODO: Remove this decorator once I have disentagled a bunch of the state management.
@MainActor
@Observable
class SearchState {
    public var searchText: String = ""

    // These are separated because SwiftUI doesn't reliably two-way bind the selection with a
    // TextField. Instead, it appears that providing a selection to the search field will cause it
    // to move the cursor, but it will not report back cursor moves on that binding, that is, it is
    // write-only.
    //
    // We hook into the UIKit backing implementation to listen to cursor changes. Initially there
    // was an implementation that bridged to UIKit and had a single Binding for reading and writing,
    // but this caused all manner of synchronization issues since things are happening on other
    // threads, or some state changes (namely a change to searchText) would cause the cursor to move
    // which would then immediately clobber any selection you had intended to change right after
    // changing the text, etc. etc.
    //
    // As it turns out, nothing ever wants to read and write cursor positions at the same time. So
    // by separating it we can maintain two unambiguous states -- desired and actual -- and
    // consumers can just interact with the one they want. Boom.
    //
    // As an additional constraint, the representation here is narrowed to only a single range so
    // that we don't have to juggle the possibility of multiple selections, which we are not
    // interested in and, in any case, UITextField doesn't seem to support anyway. It also means we
    // can define some of our own semantics, namely, that an empty range is still considered a point
    // insertion.
    public var desiredSearchSelection: Range<String.Index> = "".startIndex..<"".endIndex
    public var actualSearchSelection: Range<String.Index> = "".startIndex..<"".endIndex

    public var filters: [SearchFilter] = []
    public var configuration = SearchConfiguration.load()
    public private(set) var results: ScryfallObjectList<Card>?
    // TODO: This should eventually be private and only expose the suggestions themselves.
    public let suggestionProvider: CombinedSuggestionProvider
    public private(set) var searchNonce = 0
    public private(set) var clearNonce = 0

    public var selectedFilter: CurrentlyHighlightedFilterFacade {
        CurrentlyHighlightedFilterFacade(inputText: searchText, inputSelection: actualSearchSelection)
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
        desiredSearchSelection = "".range
        filters = []
        results = nil
        clearNonce += 1
    }

    public func clearWarnings() {
        results?.clearWarnings()
    }

    public func performSearch() {
        logger.info("starting new search", metadata: [
            "filters": "\(filters)",
            "configuration": "\(configuration)",
        ])

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
