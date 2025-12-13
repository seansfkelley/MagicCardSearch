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
    case name(NameSuggestion)
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

// FIXME: Weird struct. It _should_ be a SearchFilter, but then correlating a SearchFilter with the
// match range gets weird, because it's in control of its own stringification, so we could end up
// picking the wrong indices if the original search query has e.g. unnecessary quoting.
struct NameSuggestion: Equatable {
    let filterText: String
    let matchRange: Range<String.Index>?
}

protocol SuggestionProvider {
    func getSuggestions(_ searchTerm: String, existingFilters: [SearchFilter], limit: Int) async -> [Suggestion]
}
