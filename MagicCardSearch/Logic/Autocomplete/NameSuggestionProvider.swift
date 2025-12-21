//
//  NameSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//
import ScryfallKit

struct NameSuggestion: Equatable {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
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
    
    func getSuggestions(for searchTerm: String, limit: Int) async -> [NameSuggestion] {
        await debouncedFetch.cancel()
        
        guard limit > 0 else {
            return []
        }
        
        let partial = PartialSearchFilter.from(searchTerm)
        
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
                let content: SearchFilterContent
                if let comparison {
                    content = .keyValue("name", comparison, cardName)
                } else {
                    content = .name(cardName, true)
                }
                
                let filter: SearchFilter = partial.negated ? .negated(content) : .basic(content)
                let filterString = filter.queryStringWithEditingRange.0
                let range = filterString.range(of: name, options: .caseInsensitive)
                return NameSuggestion(filter: filter, matchRange: range)
            }
         )
    }
}
