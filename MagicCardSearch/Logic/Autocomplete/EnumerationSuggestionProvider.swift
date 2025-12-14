//
//  EnumerationSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
struct EnumerationSuggestion: Equatable {
    struct Option: Equatable {
        let value: String
        let range: Range<String.Index>?
    }
    
    let filterType: String
    let comparison: Comparison
    let options: [Option]
}

struct EnumerationSuggestionProvider {
    func getSuggestions(for searchTerm: String, limit: Int) -> [EnumerationSuggestion] {
        guard limit > 0 else {
            return []
        }
        
        // Some enumeration types, like rarity, are considered orderable, hence the comparison operators here.
        guard let match = try? /^(-?)([a-zA-Z]+)(:|=|!=|>=|>|<=|<)/.prefixMatch(in: searchTerm) else {
            return []
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
                return [
                    EnumerationSuggestion(
                        filterType: "\(negated)\(filterTypeName.lowercased())",
                        comparison: comparison!,
                        options: matchingOptions,
                    ),
                ]
            } else {
                return []
            }
        } else {
            return []
        }
    }
}
