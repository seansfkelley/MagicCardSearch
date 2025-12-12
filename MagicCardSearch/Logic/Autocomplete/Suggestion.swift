//
//  Suggestion.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
enum Suggestion: Equatable {
    case history(HistorySuggestion)
    case filter(FilterTypeSuggestion)
    case enumeration(EnumerationSuggestion)
}

struct HistorySuggestion: Equatable {
    let filter: SearchFilter
    let isPinned: Bool
    let matchRange: Range<String.Index>?
}

struct FilterTypeSuggestion: Equatable {
    let filterType: String
    let matchRange: Range<String.Index>
    let comparisonKinds: ScryfallFilterType.ComparisonKinds
}

struct EnumerationSuggestion: Equatable {
    struct Option: Equatable {
        let value: String
        let range: Range<String.Index>?
    }
    
    let filterType: String
    let comparison: Comparison
    let options: [Option]
}

protocol SuggestionProvider {
    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter], limit: Int) -> [Suggestion]
}
