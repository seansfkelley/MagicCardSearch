//
//  ReverseEnumerationSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-27.
//
import Algorithms

struct ReverseEnumerationSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let canonicalFilterName: String
    let value: String
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

struct ReverseEnumerationSuggestionProvider {
    //    private static let shared = MemoryCache<CacheKey, IndexedEnumerationValues<String>>(expiration: .never)
    
    func getSuggestions(for partial: PartialSearchFilter, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [ReverseEnumerationSuggestion] {
        guard limit > 0,
                case .name(let isExact, let partialTerm) = partial.content,
                !isExact,
                case .bare(let searchTerm) = partialTerm,
                searchTerm.count >= 2 else {
            return []
        }

        let options = Self.getIndex()

        let prefixMatches = Array(options.matching(prefix: searchTerm, sorted: .byLength))

        var prefixSet: Set<String>?
        let substringMatches = options.matching(anywhere: searchTerm, sorted: .byLength).filter { option in
            if prefixSet == nil {
                prefixSet = Set(prefixMatches.map { $0.value.0 })
            }
            return !prefixSet!.contains(option.value.0)
        }

        // TODO: Condense these together and calculate ranges properly.
        return Array(
            chain(
                prefixMatches.lazy.flatMap { match in
                    match.value.1.map { filter in
                        ReverseEnumerationSuggestion(
                            canonicalFilterName: filter.canonicalName,
                            value: match.value.0,
                            matchRange: nil,
                            prefixKind: .effective,
                            suggestionLength: filter.canonicalName.count + match.value.0.count,
                        )
                    }
                },
                substringMatches.flatMap { match in
                    match.value.1.map { filter in
                        ReverseEnumerationSuggestion(
                            canonicalFilterName: filter.canonicalName,
                            value: match.value.0,
                            matchRange: nil,
                            prefixKind: .none,
                            suggestionLength: filter.canonicalName.count + match.value.0.count,
                        )
                    }
                },
            )
            .prefix(limit)
        )
    }

    static func getIndex() -> IndexedEnumerationValues<(String, [ScryfallFilterType])> {
        var valueToFilters: [String: [ScryfallFilterType]] = [:]
        
        for filterType in scryfallFilterTypes {
            guard let enumerationValues = filterType.enumerationValues else {
                continue
            }
            
            for value in enumerationValues.all(sorted: .alphabetically) {
                valueToFilters[value, default: []].append(filterType)
            }
        }
        
        return IndexedEnumerationValues(Array(valueToFilters)) { $0.0 }
    }
}
