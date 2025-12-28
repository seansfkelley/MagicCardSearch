//
//  ReverseEnumerationSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-27.
//
struct ReverseEnumerationSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let canonicalFilterName: String
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

//struct ReverseEnumerationSuggestionProvider: SuggestionProvider {
//    func suggestions(for text: String) throws -> [String] {
//        return try MagicCardAPI.shared.cards(for: text).map(\.name).reversed()
//    }
//}
