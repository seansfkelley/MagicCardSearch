import ScryfallKit

struct NameSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

protocol CardNameFetcher: Sendable {
    func fetch(_ query: String) async -> [String]
}

struct ScryfallCardNameFetcher: CardNameFetcher {
    func fetch(_ query: String) async -> [String] {
        do {
            let client = ScryfallClient(networkLogLevel: .minimal)
            let catalog = try await client.getCardNameAutocomplete(query: query)
            return catalog.data
        } catch {
            // Swallow errors.
            return []
        }
    }
}

struct NameSuggestionProvider {
    private let debouncedFetch: Debounce<String, [String]>
    
    init(fetcher: CardNameFetcher = ScryfallCardNameFetcher(), debounce: Duration = .milliseconds(300)) {
        self.debouncedFetch = Debounce({ query in
            await fetcher.fetch(query)
        }, for: debounce)
    }
    
    func getSuggestions(for partial: PartialSearchFilter, limit: Int) async -> [NameSuggestion] {
        await debouncedFetch.cancel()
        
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
        
        let suggestions = await debouncedFetch(name) ?? []
        
        return Array(suggestions
            .lazy
            .prefix(limit)
            .map { cardName in
                let filter: SearchFilter
                if let comparison {
                    filter = SearchFilter.basic(partial.negated, "name", comparison, cardName)
                } else {
                    filter = SearchFilter.name(partial.negated, true, cardName)
                }

                // TODO: We can do better than this; we know where it should be!
                let range = filter.description.range(of: name, options: .caseInsensitive)
                return NameSuggestion(
                    filter: filter,
                    matchRange: range,
                    prefixKind: cardName.range(of: name, options: [.caseInsensitive, .anchored]) == nil ? .none : (cardName.contains(" ") || partial.negated ? .effective : .actual),
                    suggestionLength: cardName.count,
                )
            }
         )
    }
}
