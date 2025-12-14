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
    
    // swiftlint:disable:next function_body_length
    func getSuggestions(for searchTerm: String, limit: Int, permitBareSearchTerm: Bool = false) async -> [NameSuggestion] {
        await debouncedFetch.cancel()
        
        guard limit > 0 else {
            return []
        }
        
        let rawPrefix: String
        let name: String
        
        // These are not constants because it makes concurrency angry for reasons I can't be bothered with.
        let unambiguousNameSearchPrefix = /^-?((!?['"]|!)|((name:|name=|name!=)['"]?))/
        // This is a bit sloppy, but prevents searching names when the user has typed something like
        // `o:"rules` which is very obviously not an attempt to find a card by name.
        let likelyBareSearchRegex = /[a-zA-Z0-9][a-zA-Z0-9'"\/ ]+/
        
        if let match = try? unambiguousNameSearchPrefix.ignoresCase().prefixMatch(in: searchTerm) {
            rawPrefix = String(searchTerm[..<match.range.upperBound])
            name = String(searchTerm[match.range.upperBound...])
        } else if permitBareSearchTerm && (try? likelyBareSearchRegex.wholeMatch(in: searchTerm)) != nil {
            rawPrefix = "!" // Upgrade to a literal match!
            name = searchTerm
        } else {
            return []
        }
        
        // Only autocomplete if there's a useful value to search for
        guard !name.isEmpty && name.count >= 2 else {
            return []
        }
        
        let suggestions = await debouncedFetch(name) ?? []
        
        let prefix: String
        if (try? /['"]$/.firstMatch(in: rawPrefix)) != nil {
            prefix = String(rawPrefix[..<rawPrefix.index(before: rawPrefix.endIndex)]).lowercased()
        } else {
            prefix = rawPrefix.lowercased()
        }
        
        return Array(suggestions
            .lazy
            .prefix(limit)
            .map { cardName in
                let quote: String
                if cardName.contains(" ") || cardName.contains("'") {
                    quote = "\""
                } else if cardName.contains("\"") {
                    quote = "'"
                } else {
                    quote = ""
                }
                
                let filterText = "\(prefix)\(quote)\(cardName)\(quote)"
                let matchRange: Range<String.Index>?
                
                if let range = cardName.range(of: name, options: .caseInsensitive) {
                    let quotedPrefixCount = prefix.count + quote.count
                    matchRange = filterText.index(range.lowerBound, offsetBy: quotedPrefixCount)..<filterText.index(range.upperBound, offsetBy: quotedPrefixCount)
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
