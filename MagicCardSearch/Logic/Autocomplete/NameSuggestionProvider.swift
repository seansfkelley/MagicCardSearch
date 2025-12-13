//
//  NameSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//
import ScryfallKit

struct NameSuggestionProvider: SuggestionProvider {
    private let debouncedFetch: Debounce<String, [String]>
    
    init(debounce: Duration = .milliseconds(300)) {
        self.debouncedFetch = Debounce(fetch, for: debounce)
    }
    
    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter], limit: Int) async -> [Suggestion] {
        await debouncedFetch.cancel()
        
        guard let match = try? /^-?(!|(!?['"])|((name:|name=|name!=)['"]?))/.prefixMatch(in: searchTerm) else {
            return []
        }
        
        if limit <= 0 {
            return []
        }
        
        let prefix = String(searchTerm[..<match.range.upperBound])
        let name = String(searchTerm[match.range.upperBound...])
        
        // Only autocomplete if there's a value to search for
        guard !name.isEmpty else {
            return []
        }
        
        let suggestions = await debouncedFetch(name) ?? []
        
        return Array(suggestions
            .lazy
            .prefix(limit)
            .map { cardName in
                let fullString = "\(prefix)\(cardName)"
                let matchRange: Range<String.Index>?
                
                // Highlight the matched portion within the card name
                if let range = cardName.range(of: name, options: .caseInsensitive) {
                    // Calculate the range in the full string
                    let offset = fullString.distance(from: fullString.startIndex, to: prefix.endIndex)
                    let startOffset = cardName.distance(from: cardName.startIndex, to: range.lowerBound)
                    let endOffset = cardName.distance(from: cardName.startIndex, to: range.upperBound)
                    
                    let fullStart = fullString.index(fullString.startIndex, offsetBy: offset + startOffset)
                    let fullEnd = fullString.index(fullString.startIndex, offsetBy: offset + endOffset)
                    matchRange = fullStart..<fullEnd
                } else {
                    matchRange = nil
                }
                
                return .name(NameSuggestion(
                    prefix: prefix,
                    cardName: cardName,
                    matchRange: matchRange
                ))
            }
         )
    }
}

@Sendable
private func fetch(_ query: String) async -> [String] {
    do {
        let client = ScryfallClient(networkLogLevel: .minimal)
        let catalog = try await client.getCardNameAutocomplete(query: query)
        return catalog.data
    } catch {
        // Swallow errors.
        return []
    }
}
