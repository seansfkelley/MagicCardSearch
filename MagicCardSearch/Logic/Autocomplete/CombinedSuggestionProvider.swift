import Foundation

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
    let pinnedFilterProvider: PinnedFilterSuggestionProvider
    let filterHistoryProvider: FilterHistorySuggestionProvider
    let filterTypeProvider: FilterTypeSuggestionProvider
    let enumerationProvider = EnumerationSuggestionProvider()
    let reverseEnumerationProvider: ReverseEnumerationSuggestionProvider
    let scryfallCatalogs: ScryfallCatalogs
    let nameProvider = NameSuggestionProvider()
    
    init(
        pinnedFilter: PinnedFilterSuggestionProvider,
        filterHistory: FilterHistorySuggestionProvider,
        filterType: FilterTypeSuggestionProvider,
        reverseEnumeration: ReverseEnumerationSuggestionProvider,
        scryfallCatalogs: ScryfallCatalogs
    ) {
        self.pinnedFilterProvider = pinnedFilter
        self.filterHistoryProvider = filterHistory
        self.filterTypeProvider = filterType
        self.reverseEnumerationProvider = reverseEnumeration
        self.scryfallCatalogs = scryfallCatalogs
    }

    func getSuggestions(for searchTerm: String, existingFilters: Set<FilterQuery<FilterTerm>>) -> AsyncStream<[Suggestion]> {
        let partial = PartialFilterTerm.from(searchTerm)
        let hasSearchTerm = !searchTerm.isEmpty

        let (outputStream, outputContinuation) = AsyncStream.makeStream(of: [Suggestion].self)
        let (batchStream, batchContinuation) = AsyncStream.makeStream(of: [Suggestion].self)

        var tasks: [Task<Void, Never>] = [
            Task { @MainActor in
                let results = self.pinnedFilterProvider.getSuggestions(for: partial, excluding: [])
                batchContinuation.yield(results.map { Suggestion.pinned($0) })
            },
            Task { @MainActor in
                let results = self.filterHistoryProvider.getSuggestions(for: searchTerm, excluding: [], limit: 20)
                batchContinuation.yield(results.map { Suggestion.filterHistory($0) })
            },
            Task { @MainActor in
                let results = self.filterTypeProvider.getSuggestions(for: partial, limit: 4)
                batchContinuation.yield(results.map { Suggestion.filter($0) })
            },
            Task { @MainActor in
                let results = self.reverseEnumerationProvider.getSuggestions(for: partial, limit: 20)
                batchContinuation.yield(results.map { Suggestion.reverseEnumeration($0) })
            },
            Task.detached {
                let results = await self.enumerationProvider.getSuggestions(
                    for: partial,
                    catalogData: EnumerationCatalogData(scryfallCatalogs: self.scryfallCatalogs),
                    excluding: [],
                    limit: 40,
                )
                batchContinuation.yield(results.map { Suggestion.enumeration($0) })
            },
        ]

        if let cardNames = self.scryfallCatalogs.cardNames {
            tasks.append(Task.detached {
                let results = await self.nameProvider.getSuggestions(for: partial, in: cardNames, limit: 10)
                batchContinuation.yield(results.map { Suggestion.name($0) })
            })
        }

        let taskCount = tasks.count

        Task {
            var pendingCount = taskCount
            var allSuggestions: [Suggestion] = []

            for await batch in batchStream {
                allSuggestions.append(contentsOf: batch)
                outputContinuation.yield(self.scoreSuggestions(allSuggestions, hasSearchTerm))
                pendingCount -= 1
                if pendingCount == 0 {
                    batchContinuation.finish()
                }
            }

            outputContinuation.finish()
        }

        return outputStream
    }
    
    private func scoreSuggestions(_ suggestions: [Suggestion], _ hasSearchTerm: Bool) -> [Suggestion] {
        if hasSearchTerm {
            suggestions.sorted(using: [
                KeyPathComparator(\.prefixKind.rawValue),
                KeyPathComparator(\.suggestionLength),
                KeyPathComparator(\.priority),
            ])
        } else {
            suggestions.sorted(using: [
                KeyPathComparator(\.priority),
                KeyPathComparator(\.prefixKind.rawValue),
                KeyPathComparator(\.suggestionLength),
            ])
        }
    }
}
