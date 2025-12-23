//
//  AutcompleteProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-07.
//

import Foundation

protocol ScorableSuggestion {
    var isPrefix: Bool { get }
    var suggestionLength: Int { get }
}

enum Suggestion: Equatable, Sendable, ScorableSuggestion {
    case pinned(PinnedFilterSuggestion)
    case history(HistorySuggestion)
    case filter(FilterTypeSuggestion)
    case enumeration(EnumerationSuggestion)
    case name(NameSuggestion)
    
    private var scorable: any ScorableSuggestion {
        switch self {
        case .pinned(let suggestion): suggestion
        case .history(let suggestion): suggestion
        case .filter(let suggestion): suggestion
        case .enumeration(let suggestion): suggestion
        case .name(let suggestion): suggestion
        }
    }
    
    var isPrefix: Bool { scorable.isPrefix }
    var suggestionLength: Int { scorable.suggestionLength }
    var priority: Int {
        switch self {
        case .pinned: return 0
        case .history: return 1
        case .filter: return 2
        case .enumeration: return 3
        case .name: return 4
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
    let nameProvider: NameSuggestionProvider
    
    let loadingState = DebouncedLoadingState()
    
    init(
        pinnedFilter: PinnedFilterSuggestionProvider,
        history: HistorySuggestionProvider,
        filterType: FilterTypeSuggestionProvider,
        enumeration: EnumerationSuggestionProvider,
        name: NameSuggestionProvider
    ) {
        self.pinnedFilterProvider = pinnedFilter
        self.historyProvider = history
        self.filterTypeProvider = filterType
        self.enumerationProvider = enumeration
        self.nameProvider = name
    }

    func getSuggestions(for searchTerm: String, existingFilters: Set<SearchFilter>) -> AsyncStream<[Suggestion]> {
        let currentTaskId = loadingState.start()
        let partial = PartialSearchFilter.from(searchTerm)
        
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
            
            let scoredSuggestions = self.scoreSuggestions(allSuggestions)
            continuation.yield(scoredSuggestions)
            
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
                
                let finalScoredSuggestions = self.scoreSuggestions(allSuggestions)
                continuation.yield(finalScoredSuggestions)
                
                loadingState.stop(for: currentTaskId)
                
                continuation.finish()
            }
        }
    }
    
    private func scoreSuggestions(_ suggestions: [Suggestion]) -> [Suggestion] {
        suggestions.sorted(using: [
            KeyPathComparator(\.isPrefix, comparator: BooleanComparator(order: .reverse)),
            KeyPathComparator(\.suggestionLength),
            KeyPathComparator(\.priority),
        ])
    }
}

private struct BooleanComparator: SortComparator {
    typealias Compared = Bool

    var order: SortOrder = .forward

    func compare(_ lhs: Bool, _ rhs: Bool) -> ComparisonResult {
        if lhs == rhs {
            .orderedSame
        } else if lhs {
            order == .forward ? .orderedDescending : .orderedAscending
        } else {
            order == .forward ? .orderedAscending : .orderedDescending
        }
    }
}
