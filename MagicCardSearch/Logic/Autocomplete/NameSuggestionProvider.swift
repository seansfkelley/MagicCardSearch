//
//  NameSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-12.
//
struct NameSuggestionProvider: SuggestionProvider {
    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter], limit: Int) -> [Suggestion] {
        guard let match = try? /^(-?)(('|")|((name:|name=|name!=)['"]?))/.prefixMatch(in: searchTerm) else {
            return []
        }
        
        if limit <= 0 {
            return []
        }
        
        let prefix = searchTerm[..<match.range.upperBound]
        let value = searchTerm[match.range.upperBound...]
        
        
    }
}
