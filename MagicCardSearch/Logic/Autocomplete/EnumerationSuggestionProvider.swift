import Foundation
import FuzzyMatch
import ScryfallKit

actor EnumerationSuggestionProvider {
    func getSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String, limit: Int) -> [Suggestion] {
        guard limit > 0,
              case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
              let comparison = partialComparison.toComplete(),
              let filterType = scryfallFilterByType[filterTypeName.lowercased()],
              let allCandidates = catalogData[filterType] ?? filterType.enumerationValues else {
            return []
        }

        let value = partialValue.incompleteContent

        let matched: [(String, Double)]
        if value.isEmpty {
            matched = allCandidates.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { ($0, 0) }
        } else {
            matched = timed("EnumerationSuggestProvider fuzzy match") {
                FuzzyMatcher().matches(allCandidates, against: value).map { ($0.candidate, $0.match.score) }
            }
        }

        let allResults = matched.map { candidate, score in
            let filter = FilterTerm.basic(partial.polarity, filterTypeName.lowercased(), comparison, candidate)
            return Suggestion(
                source: .enumeration,
                content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
                score: score,
            )
        }

        return Array(allResults.prefix(limit))
    }
}
