import ScryfallKit
import OSLog
import FuzzyMatch

private let logger = Logger(subsystem: "MagicCardSearch", category: "NameSuggestionProvider")

struct NameSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: FilterTerm
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

@MainActor
struct NameSuggestionProvider {
    let scryfallCatalogs: ScryfallCatalogs

    func getSuggestions(for partial: PartialFilterTerm, limit: Int) -> [NameSuggestion] {
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

        let matcher = FuzzyMatcher()
        let query = matcher.prepare(name)
        var buffer = matcher.makeBuffer()

        // Without the type annotations on this line, the compiler loops forever. Really. Try below:
        //   let results = (scryfallCatalogs.cardNames ?? []).compactMap { candidate in
        let results: [(String, ScoredMatch)] = (scryfallCatalogs.cardNames ?? []).compactMap { candidate -> (String, ScoredMatch)? in
            guard let match = matcher.score(candidate, against: query, buffer: &buffer) else {
                return nil
            }
            return (candidate, match)
        }

        return Array(results
            .sorted { $0.1.score > $1.1.score }
            .lazy
            .prefix(limit)
            .map { cardName, match in
                let filter: FilterTerm
                if let comparison {
                    filter = .basic(partial.polarity, "name", comparison, cardName)
                } else {
                    filter = .name(partial.polarity, true, cardName)
                }

                // TODO: We can do better than this; we know where it should be!
                let range = filter.description.range(of: name, options: .caseInsensitive)
                return NameSuggestion(
                    filter: filter,
                    matchRange: range,
                    prefixKind: cardName.range(of: name, options: [.caseInsensitive, .anchored]) == nil ? .none : (cardName.contains(" ") || partial.polarity == .negative ? .effective : .actual),
                    suggestionLength: cardName.count,
                )
            }
         )
    }
}
