//
//  EnumerationSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
struct EnumerationSuggestionProvider: SuggestionProvider {
    static func getSuggestions(_ searchTerm: String) -> [Suggestion] {
        // Some enumeration types, like rarity, are considered orderable, hence the comparison operators here.
        guard let match = try? /^(-?)([a-zA-Z]+)(:|=|!=|>=|>|<=|<)/.prefixMatch(in: searchTerm) else {
            return nil
        }
        
        let (_, negated, filterTypeName, comparisonOperator) = match.output
        let value = searchTerm[match.range.upperBound...]
        
        if let filterType = scryfallFilterByType[filterTypeName.lowercased()], let options = filterType.enumerationValues {
            var matchingOptions: [EnumerationSuggestion.Option] = []

            if value.isEmpty {
                matchingOptions = options.sorted().map { .init(value: $0, range: nil) }
            } else {
                var matches: [(option: String, range: Range<String.Index>)] = []

                for option in options {
                    if let range = option.range(of: value, options: .caseInsensitive) {
                        matches.append((option, range))
                    }
                }

                matches.sort { $0.option.count < $1.option.count }
                matchingOptions = matches.map { .init(value: $0.option, range: $0.range) }
            }

            if !matchingOptions.isEmpty {
                let comparison = Comparison(rawValue: String(comparisonOperator))
                assert(comparison != nil) // if it is, programmer error on the regex or enumeration type
                return .enumeration(EnumerationSuggestion(
                    filterType: "\(negated)\(filterTypeName.lowercased())",
                    comparison: comparison!,
                    options: matchingOptions,
                ))
            } else {
                return []
            }
        } else {
            return []
        }
    }
}
