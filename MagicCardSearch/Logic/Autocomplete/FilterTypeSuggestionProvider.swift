//
//  FilterTypeSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
struct FilterTypeSuggestion: Equatable {
    let filterType: String
    let matchRange: Range<String.Index>
    let comparisonKinds: ScryfallFilterType.ComparisonKinds
}

// TODO: Make this even lazier for performance.
struct FilterTypeSuggestionProvider {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func getSuggestions(for searchTerm: String, limit: Int) -> [FilterTypeSuggestion] {
        guard let match = try? /^(-?)([a-zA-Z]+)$/.wholeMatch(in: searchTerm) else {
            return []
        }
        
        guard limit > 0 else {
            return []
        }
        
        let (_, negated, filterName) = match.output
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
            let filterType = String(filterName) // make it not a substring so the indices are sane
            suggestions
                .insert(
                    FilterTypeSuggestion(
                        filterType: filterType,
                        matchRange: filterType.startIndex..<filterType.endIndex,
                        comparisonKinds: exactMatch.comparisonKinds,
                    ),
                    at: 0
                )
        }
        
        if !negated.isEmpty {
            suggestions = suggestions.map {
                let prefixed = "\(negated)\($0.filterType)"
                return FilterTypeSuggestion(
                    filterType: prefixed,
                    matchRange: prefixed.index(after: $0.matchRange.lowerBound)..<prefixed.index(after: $0.matchRange.upperBound),
                    comparisonKinds: $0.comparisonKinds,
                )
            }
        }
        
        return Array(suggestions.prefix(limit))
    }
}
