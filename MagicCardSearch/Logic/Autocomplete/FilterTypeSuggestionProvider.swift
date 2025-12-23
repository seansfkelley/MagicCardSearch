//
//  FilterTypeSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
struct FilterTypeSuggestion: Equatable, Sendable, ScorableSuggestion {
    let filterType: String
    let matchRange: Range<String.Index>
    let comparisonKinds: ScryfallFilterType.ComparisonKinds
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

// TODO: Make this even lazier for performance.
struct FilterTypeSuggestionProvider {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func getSuggestions(for partial: PartialSearchFilter, limit: Int) -> [FilterTypeSuggestion] {
        guard limit > 0 else {
            return []
        }
        
        guard case .name(let exact, let partialTerm) = partial.content else {
            return []
        }
        
        guard !exact else {
            return []
        }
        
        guard partialTerm.quotingType == nil else {
            return []
        }
            
        let filterName = partialTerm.incompleteContent
        let exactMatch = scryfallFilterByType[filterName.lowercased()]
        
        var suggestions: [FilterTypeSuggestion] = []
        
        for filterType in scryfallFilterTypes {
            if filterType.canonicalName == exactMatch?.canonicalName {
                continue
            }
            
            var bestMatch: FilterTypeSuggestion?
            
            for candidate in filterType.allNames {
                if let range = candidate.range(of: filterName, options: .caseInsensitive) {
                    let match = FilterTypeSuggestion(
                        filterType: candidate,
                        matchRange: range,
                        comparisonKinds: filterType.comparisonKinds,
                        prefixKind: range.lowerBound == candidate.startIndex ? .actual : .none,
                        suggestionLength: candidate.count,
                    )
                    if let existing = bestMatch {
                        if range.lowerBound == candidate.startIndex && existing.matchRange.lowerBound != existing.filterType.startIndex {
                            bestMatch = match
                        } else if candidate.count < existing.filterType.count {
                            bestMatch = match
                        }
                    } else {
                        bestMatch = match
                    }
                }
            }
            
            if let match = bestMatch {
                suggestions.append(match)
            }
        }

        suggestions.sort { lhs, rhs in
            if lhs.matchRange.lowerBound == rhs.matchRange.lowerBound {
                lhs.filterType.count < rhs.filterType.count
            } else if lhs.matchRange.lowerBound == lhs.filterType.startIndex {
                true
            } else {
                lhs.filterType.count < rhs.filterType.count
            }
        }
        
        if let exactMatch {
            suggestions
                .insert(
                    FilterTypeSuggestion(
                        filterType: filterName,
                        matchRange: filterName.range,
                        comparisonKinds: exactMatch.comparisonKinds,
                        prefixKind: .actual,
                        suggestionLength: filterName.count,
                    ),
                    at: 0
                )
        }
        
        if partial.negated {
            suggestions = suggestions.map {
                let matchIsAtBeginning = $0.matchRange.lowerBound == $0.filterType.startIndex
                let prefixed = "-\($0.filterType)"
                let range = matchIsAtBeginning
                ? $0.matchRange.lowerBound..<prefixed.index(after: $0.matchRange.upperBound)
                : $0.matchRange.shift(with: prefixed, by: 1)

                return FilterTypeSuggestion(
                    filterType: prefixed,
                    matchRange: range,
                    comparisonKinds: $0.comparisonKinds,
                    prefixKind: $0.prefixKind,
                    suggestionLength: $0.suggestionLength + (matchIsAtBeginning ? 1 : 0),
                )
            }
        }
        
        return Array(suggestions.prefix(limit))
    }
}
