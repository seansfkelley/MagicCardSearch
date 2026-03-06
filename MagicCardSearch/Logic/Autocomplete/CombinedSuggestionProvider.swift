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

        let (stream, continuation) = AsyncStream.makeStream(of: [Suggestion].self)

        let task = Task {
            await withTaskGroup(of: [Suggestion].self) { group in
                group.addTask { @MainActor in
                    self.pinnedFilterProvider.getSuggestions(for: partial, excluding: [])
                        .map { Suggestion.pinned($0) }
                }
                group.addTask { @MainActor in
                    self.filterHistoryProvider.getSuggestions(for: searchTerm, excluding: [], limit: 20)
                        .map { Suggestion.filterHistory($0) }
                }
                group.addTask { @MainActor in
                    self.filterTypeProvider.getSuggestions(for: partial, limit: 4)
                        .map { Suggestion.filter($0) }
                }
                group.addTask { @MainActor in
                    self.reverseEnumerationProvider.getSuggestions(for: partial, limit: 20)
                        .map { Suggestion.reverseEnumeration($0) }
                }
                group.addTask {
                    await self.enumerationProvider.getSuggestions(
                        for: partial,
                        catalogData: EnumerationCatalogData(scryfallCatalogs: self.scryfallCatalogs),
                        excluding: [],
                        limit: 40,
                    ).map { Suggestion.enumeration($0) }
                }
                if let cardNames = self.scryfallCatalogs.cardNames {
                    group.addTask {
                        await self.nameProvider.getSuggestions(for: partial, in: cardNames, limit: 10)
                            .map { Suggestion.name($0) }
                    }
                }

                var allSuggestions: [Suggestion] = []
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
