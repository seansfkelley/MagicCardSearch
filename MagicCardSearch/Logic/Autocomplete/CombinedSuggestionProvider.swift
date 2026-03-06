import Foundation
import SQLiteData

enum PrefixKind: Int {
    // The search term is literally the character-for-character prefix of the suggestion.
    case actual = 1
    // The search term is more or less the prefix, accounting for low-significance formatting
    // characters like required quotes, or a negation operator.
    case effective = 2
    // The search term is not a prefix under any interpretation.
    case none = 3
}

protocol ScorableSuggestion {
    var prefixKind: PrefixKind { get }
    var suggestionLength: Int { get }
}

struct WithHighlightedString<T> {
    let value: T
    let string: String
    lazy var highlights = guessHighlights()

    private let searchTerm: String

    init(value: T, string: String, searchTerm: String) {
        self.value = value
        self.string = string
        self.searchTerm = searchTerm
    }

    private func guessHighlights() -> [Range<String.Index>] {
        // TODO: Calculate by stepping through string and searchTerm, greedily picking every one
        // that matches. May take multiple passes if searchTerm includes characters that never
        // appear in string that precede values that _do_ appear.
        []
    }
}

struct Suggestion2 {
    enum Source {
        case pinnedFilter, historyFilter, filterType, enumeration, reverseEnumeration, name
    }

    enum Content {
        case string(WithHighlightedString<String>)
        case filter(WithHighlightedString<FilterQuery<FilterTerm>>)
        case filterParts(Polarity, ScryfallFilterType, WithHighlightedString<String>)
    }

    let source: Source
    let content: Content
    let score: Double
}

enum Suggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    case pinned(PinnedFilterSuggestion)
    case filterHistory(FilterHistorySuggestion)
    case filter(FilterTypeSuggestion)
    case enumeration(EnumerationSuggestion)
    case reverseEnumeration(ReverseEnumerationSuggestion)
    case name(NameSuggestion)
    
    private var scorable: any ScorableSuggestion {
        switch self {
        case .pinned(let suggestion): suggestion
        case .filterHistory(let suggestion): suggestion
        case .filter(let suggestion): suggestion
        case .enumeration(let suggestion): suggestion
        case .reverseEnumeration(let suggestion): suggestion
        case .name(let suggestion): suggestion
        }
    }
    
    var prefixKind: PrefixKind { scorable.prefixKind }
    var suggestionLength: Int { scorable.suggestionLength }
    var priority: Int {
        switch self {
        case .pinned: return 0
        case .filterHistory: return 1
        case .filter: return 2
        case .enumeration: return 3
        case .reverseEnumeration: return 4
        case .name: return 5
        }
    }
}

@MainActor
@Observable
class CombinedSuggestionProvider {
    private let pinnedFilterProvider = PinnedFilterSuggestionProvider()
    private let filterHistoryProvider = FilterHistorySuggestionProvider()
    private let filterTypeProvider = FilterTypeSuggestionProvider()
    private let enumerationProvider = EnumerationSuggestionProvider()
    private let reverseEnumerationProvider = ReverseEnumerationSuggestionProvider()
    private let nameProvider = NameSuggestionProvider()
    private let scryfallCatalogs: ScryfallCatalogs

    @ObservationIgnored @FetchAll private var pinnedFilters: [PinnedFilterEntry]
    @ObservationIgnored @FetchAll(FilterHistoryEntry.order { $0.lastUsedAt.desc() }) private var filterHistoryEntries

    init(scryfallCatalogs: ScryfallCatalogs) {
        self.scryfallCatalogs = scryfallCatalogs
    }

    func getSuggestions(for searchTerm: String, existingFilters: Set<FilterQuery<FilterTerm>>) -> AsyncStream<[Suggestion2]> {
        let partial = PartialFilterTerm.from(searchTerm)

        let (stream, continuation) = AsyncStream.makeStream(of: [Suggestion2].self)

        let task = Task {
            await withTaskGroup(of: [Suggestion2].self) { group in
                let catalogData = EnumerationCatalogData(scryfallCatalogs: self.scryfallCatalogs)

                do {
                    let filters = pinnedFilters
                    group.addTask {
                        self.pinnedFilterProvider.getSuggestions(for: partial, from: filters, searchTerm: searchTerm)
                    }
                }
                do {
                    let history = filterHistoryEntries
                    group.addTask {
                        self.filterHistoryProvider.getSuggestions(for: searchTerm, from: history, limit: 20)
                    }
                }
                group.addTask {
                    self.filterTypeProvider.getSuggestions(for: partial, searchTerm: searchTerm, limit: 4)
                }
                group.addTask {
                    await self.reverseEnumerationProvider.getSuggestions(for: partial, catalogData: catalogData, searchTerm: searchTerm, limit: 20)
                }
                group.addTask {
                    await self.enumerationProvider.getSuggestions(
                        for: partial,
                        catalogData: catalogData,
                        excluding: [],
                        searchTerm: searchTerm,
                        limit: 40,
                    )
                }
                if let cardNames = self.scryfallCatalogs.cardNames {
                    group.addTask {
                        await self.nameProvider.getSuggestions(for: partial, in: cardNames, searchTerm: searchTerm, limit: 10)
                    }
                }

                var allSuggestions: [Suggestion2] = []
                for await batch in group {
                    allSuggestions.append(contentsOf: batch)
                    continuation.yield(self.scoreSuggestions(allSuggestions, !searchTerm.isEmpty))
                }
                continuation.finish()
            }
        }

        continuation.onTermination = { _ in task.cancel() }

        return stream
    }

    private func scoreSuggestions(_ suggestions: [Suggestion2], _ hasSearchTerm: Bool) -> [Suggestion2] {
        if hasSearchTerm {
            suggestions.sorted { $0.score > $1.score }
        } else {
            suggestions.sorted { $0.score > $1.score }
        }
    }
}
