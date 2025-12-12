//
//  NameSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//
import ScryfallKit

@Sendable
func logEvent(_ category: String, _ action: String) async {
    print("Logged \(category) - \(action)")
}

let logDebounced = Debounce(logEvent, for: .milliseconds(500))

struct NameSuggestionProvider: SuggestionProvider {
    /// Debounce interval in nanoseconds (300ms)
    private let debounceInterval: UInt64 = 300_000_000
    private let getDebounced: @Sendable (String, [SearchFilter], Int) -> [Suggestion]
    
    init() {
        self.getDebounced = Debounce(self.get_, for: .milliseconds(300))
    }
    
    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter], limit: Int) async -> [Suggestion] {
        return getDebounced(searchTerm, existingFilters, limit)
    }
    
    @Sendable
    private func get_(_ searchTerm: String, existingFilters: [SearchFilter], limit: Int) async -> [Suggestion] {
        guard let match = try? /^(-?)(('|")|((name:|name=|name!=)['"]?))/.prefixMatch(in: searchTerm) else {
            return []
        }
        
        if limit <= 0 {
            return []
        }
        
        let prefix = String(searchTerm[..<match.range.upperBound])
        let value = String(searchTerm[match.range.upperBound...])
        
        // Only autocomplete if there's a value to search for
        guard !value.isEmpty else {
            return []
        }
        
        // Debounce: wait before making the network request
        try? await Task.sleep(nanoseconds: debounceInterval)
        
        // Check if task was cancelled during debounce
        guard !Task.isCancelled else {
            return []
        }
        
        do {
            // Use ScryfallKit's autocomplete API
            let client = ScryfallClient(networkLogLevel: .minimal)
            let catalog = try await client.getCardNameAutocomplete(query: value)
            
            // Return up to `limit` suggestions
            return catalog.data.prefix(limit).map { cardName in
                let fullString = "\(prefix)\(cardName)"
                let matchRange: Range<String.Index>?
                
                // Highlight the matched portion within the card name
                if let range = cardName.range(of: value, options: .caseInsensitive) {
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
        } catch {
            // If the API call fails, just return empty suggestions
            return []
        }
    }
}
