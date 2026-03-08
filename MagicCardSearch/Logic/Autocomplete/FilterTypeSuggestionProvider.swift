import FuzzyMatch

struct FilterTypeSuggestionProvider {
    func getSuggestions(for partial: PartialFilterTerm, searchTerm: String, limit: Int) -> [Suggestion] {
        guard limit > 0,
            case .name(let exact, let partialTerm) = partial.content,
            !exact,
            partialTerm.quotingType == nil else {
            return []
        }

        let filterName = partialTerm.incompleteContent

        if filterName.isEmpty {
            return []
        }

        var seen = Set<String>()
        var deduplicated: [(String, ScryfallFilterType, Double)] = []
        for result in FuzzyMatcher().matches(Array(scryfallFilterByType.keys), against: filterName) {
            if let filterType = scryfallFilterByType[result.candidate], seen.insert(filterType.canonicalName).inserted {
                deduplicated.append((result.candidate, filterType, result.match.score))
            }
        }

        return Array(deduplicated.prefix(limit).map { candidate, filterType, score in
            let displayName = partial.polarity == .negative ? "-\(candidate)" : candidate
            return Suggestion(
                source: .filterType,
                content: .filterType(WithHighlightedString(value: FilterTypeSuggestion(polarity: partial.polarity, filterType: filterType), string: displayName, searchTerm: searchTerm)),
                score: score,
            )
        })
    }
}
