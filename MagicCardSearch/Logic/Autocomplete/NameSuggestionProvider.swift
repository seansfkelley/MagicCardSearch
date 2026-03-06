import ScryfallKit
import FuzzyMatch

struct NameSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: FilterTerm
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

actor NameSuggestionProvider {
    private let matcher = FuzzyMatcher()

    func getSuggestions(for partial: PartialFilterTerm, in cardNames: [String], searchTerm: String, limit: Int) -> [Suggestion2] {
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

        return Array(matcher.matches(cardNames, against: name)
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

                return Suggestion2(
                    source: .name,
                    content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
                    score: result.match.score,
                )
            }
         )
    }
}
