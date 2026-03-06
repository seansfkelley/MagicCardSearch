struct FilterTypeSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filterType: String
    let matchRange: Range<String.Index>
    let comparisonKinds: ScryfallFilterType.ComparisonKinds
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

struct FilterTypeSuggestionProvider {
    // swiftlint:disable:next cyclomatic_complexity function_body_length
    func getSuggestions(for partial: PartialFilterTerm, searchTerm: String, limit: Int) -> [Suggestion2] {
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

        var suggestions: [(String, ScryfallFilterType)] = []

        for filterType in scryfallFilterTypes {
            if filterType.canonicalName == exactMatch?.canonicalName {
                continue
            }

            var bestCandidate: String?

            for candidate in filterType.allNames {
                if let range = candidate.range(of: filterName, options: .caseInsensitive) {
                    if let existing = bestCandidate {
                        if range.lowerBound == candidate.startIndex && existing.range(of: filterName, options: .caseInsensitive)?.lowerBound != existing.startIndex {
                            bestCandidate = candidate
                        } else if candidate.count < existing.count {
                            bestCandidate = candidate
                        }
                    } else {
                        bestCandidate = candidate
                    }
                }
            }

            if let candidate = bestCandidate {
                suggestions.append((candidate, filterType))
            }
        }

        suggestions.sort { lhs, rhs in
            let lhsRange = lhs.0.range(of: filterName, options: .caseInsensitive)!
            let rhsRange = rhs.0.range(of: filterName, options: .caseInsensitive)!
            return if lhsRange.lowerBound == rhsRange.lowerBound {
                lhs.0.count < rhs.0.count
            } else if lhsRange.lowerBound == lhs.0.startIndex {
                true
            } else {
                lhs.0.count < rhs.0.count
            }
        }

        if let exactMatch {
            suggestions.insert((filterName, exactMatch), at: 0)
        }

        return Array(suggestions.prefix(limit).map { candidate, filterType in
            let displayName = partial.polarity == .negative ? "-\(candidate)" : candidate
            return Suggestion2(
                source: .filterType,
                content: .filterParts(partial.polarity, filterType, WithHighlightedString(value: candidate, string: displayName, searchTerm: searchTerm)),
                score: 0,
            )
        })
    }
}
