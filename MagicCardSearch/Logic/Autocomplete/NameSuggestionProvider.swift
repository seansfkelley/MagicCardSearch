//
//  NameSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//
import ScryfallKit

// FIXME: Weird struct. It _should_ be a SearchFilter, but then correlating a SearchFilter with the
// match range gets weird, because it's in control of its own stringification, so we could end up
// picking the wrong indices if the original search query has e.g. unnecessary quoting.
struct NameSuggestion: Equatable {
    let filterText: String
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
        
        guard let match = try? /^-?(!|(!?['"])|((name:|name=|name!=)['"]?))/.prefixMatch(in: searchTerm) else {
            return []
        }
        
        guard limit > 0 else {
            return []
        }
        
        let prefix = String(searchTerm[..<match.range.upperBound])
        let name = String(searchTerm[match.range.upperBound...])
        
        // Only autocomplete if there's a useful value to search for
        guard !name.isEmpty && name.count >= 2 else {
            return []
        }
        
        let suggestions = await debouncedFetch(name) ?? []
        
        return Array(suggestions
            .lazy
            .prefix(limit)
            .map { cardName in
                let suffix: String
                if prefix.contains("\"") {
                    suffix = "\""
                } else if prefix.contains("'") {
                    suffix = "'"
                } else {
                    suffix = ""
                }
                
                let filterText = "\(prefix)\(cardName)\(suffix)"
                
                let matchRange: Range<String.Index>?
                
                if let range = cardName.range(of: name, options: .caseInsensitive) {
                    matchRange = filterText.index(range.lowerBound, offsetBy: prefix.count)..<filterText.index(range.upperBound, offsetBy: prefix.count)
                } else {
                    matchRange = nil
                }
                
                return NameSuggestion(
                    filterText: filterText,
                    matchRange: matchRange
                )
            }
         )
    }
}
