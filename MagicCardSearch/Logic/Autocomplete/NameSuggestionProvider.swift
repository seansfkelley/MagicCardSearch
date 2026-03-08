import ScryfallKit
import FuzzyMatch

actor NameSuggestionProvider {
    func getSuggestions(for partial: PartialFilterTerm, in cardNames: [String], searchTerm: String, limit: Int) -> [Suggestion] {
        guard limit > 0 else {
            return []
        }

        let name: String
        let comparison: Comparison?

        switch partial.content {
        case .name(_, let partialValue):
            name = partialValue.incompleteContent
            comparison = nil
        case .filter(let filter, let partialComparison, let partialValue):
            if let completeComparison = partialComparison.toComplete(), filter.lowercased() == "name" && (
                completeComparison == .including || completeComparison == .equal || completeComparison == .notEqual
            ) {
                name = partialValue.incompleteContent
                comparison = completeComparison
            } else {
                name = ""
                comparison = nil
            }
        }

        guard name.count >= 2 else {
            return []
        }

        let matches = timed("NameSuggestionProvider fuzzy match") {
            FuzzyMatcher().matches(cardNames, against: name)
        }

        return Array(matches
            .lazy
            .prefix(limit)
            .map { result in
                let cardName = result.candidate
                let filter: FilterTerm
                if let comparison {
                    filter = .basic(partial.polarity, "name", comparison, cardName)
                } else {
                    filter = .name(partial.polarity, true, cardName)
                }

                return Suggestion(
                    source: .name,
                    content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
                    score: result.match.score,
                )
            }
         )
    }
}
