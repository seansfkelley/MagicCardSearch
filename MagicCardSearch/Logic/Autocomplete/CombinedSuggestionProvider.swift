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
    case history(HistorySuggestion)
    case filter(FilterTypeSuggestion)
    case enumeration(EnumerationSuggestion)
    case reverseEnumeration(ReverseEnumerationSuggestion)
    case name(NameSuggestion)
    
    private var scorable: any ScorableSuggestion {
        switch self {
        case .pinned(let suggestion): suggestion
        case .history(let suggestion): suggestion
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
        case .history: return 1
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
    let historyProvider: HistorySuggestionProvider
    let filterTypeProvider: FilterTypeSuggestionProvider
    let enumerationProvider: EnumerationSuggestionProvider
    let reverseEnumerationProvider: ReverseEnumerationSuggestionProvider
    let nameProvider: NameSuggestionProvider
    
    let loadingState = DebouncedLoadingState()
    
    init(
        pinnedFilter: PinnedFilterSuggestionProvider,
        history: HistorySuggestionProvider,
        filterType: FilterTypeSuggestionProvider,
        enumeration: EnumerationSuggestionProvider,
        reverseEnumeration: ReverseEnumerationSuggestionProvider,
        name: NameSuggestionProvider
    ) {
        self.pinnedFilterProvider = pinnedFilter
        self.historyProvider = history
        self.filterTypeProvider = filterType
        self.enumerationProvider = enumeration
        self.reverseEnumerationProvider = reverseEnumeration
        self.nameProvider = name
    }

    func getSuggestions(for searchTerm: String, existingFilters: Set<FilterQuery<FilterTerm>>) -> AsyncStream<[Suggestion]> {
        let currentTaskId = loadingState.start()
        let partial = PartialFilterTerm.from(searchTerm)
        
        return AsyncStream<[Suggestion]> { continuation in
            var allSuggestions: [Suggestion] = []
            var excludedFilters = Set(existingFilters)
            
            let pinnedSuggestions = self.pinnedFilterProvider.getSuggestions(
                for: partial,
                excluding: excludedFilters,
            )
            allSuggestions.append(contentsOf: pinnedSuggestions.map { Suggestion.pinned($0) })
            excludedFilters.formUnion(pinnedSuggestions.map { $0.filter })
            
            let historySuggestions = self.historyProvider.getSuggestions(
                for: searchTerm,
                excluding: excludedFilters,
                limit: 20
            )
            allSuggestions.append(contentsOf: historySuggestions.map { Suggestion.history($0) })
            excludedFilters.formUnion(historySuggestions.map { $0.filter })
            
            let filterSuggestions = self.filterTypeProvider.getSuggestions(
                for: partial,
                limit: 4
            )
            allSuggestions.append(contentsOf: filterSuggestions.map { Suggestion.filter($0) })
            
            let enumerationSuggestions = self.enumerationProvider.getSuggestions(
                for: partial,
                excluding: excludedFilters,
                limit: 40
            )
            allSuggestions.append(contentsOf: enumerationSuggestions.map { Suggestion.enumeration($0) })
            
            let reverseEnumerationSuggestions = self.reverseEnumerationProvider.getSuggestions(
                for: partial,
                limit: 20
            )
            allSuggestions.append(contentsOf: reverseEnumerationSuggestions.map { Suggestion.reverseEnumeration($0) })
            
            continuation.yield(self.scoreSuggestions(allSuggestions, !searchTerm.isEmpty))

            guard loadingState.isStillCurrent(id: currentTaskId) else {
                continuation.finish()
                return
            }
                
            Task {
                let nameSuggestions = await self.nameProvider.getSuggestions(
                    for: partial,
                    limit: 10,
                )
                
                guard loadingState.isStillCurrent(id: currentTaskId), !Task.isCancelled else {
                    continuation.finish()
                    return
                }
                
                allSuggestions.append(contentsOf: nameSuggestions.map { Suggestion.name($0) })

                continuation.yield(self.scoreSuggestions(allSuggestions, !searchTerm.isEmpty))

                loadingState.stop(for: currentTaskId)
                
                continuation.finish()
            }
        }
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
