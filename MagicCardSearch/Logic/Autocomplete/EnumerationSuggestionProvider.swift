//
//  EnumerationSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
import ScryfallKit

struct EnumerationSuggestion: Equatable {
    struct Option: Equatable {
        let value: String
        let range: Range<String.Index>?
    }
    
    let isNegated: Bool
    let filterType: String
    let comparison: Comparison
    let options: [Option]
}

private enum CacheKey: Hashable {
    case type
    case set
    case block
    case keyword
    case watermark
}

@MainActor
struct EnumerationSuggestionProvider {
    private static let shared = MemoryCache<CacheKey, Set<String>>(expiration: .never)
    
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
        
        guard let filterType = scryfallFilterByType[filterTypeName.lowercased()] else {
            return []
        }
        
        let options: Set<String>
        if let cacheKey = Self.cacheKey(for: filterType.canonicalName) {
            options = Self.getOptionsFromCache(for: cacheKey)
        } else if let staticOptions = filterType.enumerationValues {
            options = staticOptions
        } else {
            return []
        }

        // TODO: Change this method to return multiple objects instead of one with a list of
        // options, and then respect the limit. Also, the limit should be higher than it is.
        var matchingOptions: [EnumerationSuggestion.Option] = []

        if value.isEmpty {
            // TODO: Should guarantee that options are sorted already for this case.
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
                    isNegated: negated.isEmpty == false,
                    filterType: filterTypeName.lowercased(),
                    comparison: comparison!,
                    options: matchingOptions,
                ),
            ]
        } else {
            return []
        }
    }
    
    // MARK: - Cache Management
    
    private static func cacheKey(for canonicalName: String) -> CacheKey? {
        switch canonicalName {
        case "type": return .type
        case "set": return .set
        case "block": return .block
        case "keyword": return .keyword
        case "watermark": return .watermark
        default: return nil
        }
    }
    
    private static func getOptionsFromCache(for key: CacheKey) -> Set<String> {
        if let options = shared[key] {
            return options
        } else {
            shared[key] = fetchOptions(for: key)
            return shared[key]!
        }
    }
    
    private static func fetchOptions(for key: CacheKey) -> Set<String> {
        let catalogs = ScryfallCatalogs.shared
        
        switch key {
        case .type:
            return [
                Self.getCatalogData(.supertypes),
                Self.getCatalogData(.cardTypes),
                Self.getCatalogData(.artifactTypes),
                Self.getCatalogData(.battleTypes),
                Self.getCatalogData(.creatureTypes),
                Self.getCatalogData(.enchantmentTypes),
                Self.getCatalogData(.landTypes),
                Self.getCatalogData(.planeswalkerTypes),
                Self.getCatalogData(.spellTypes),
            ].reduce(into: Set<String>()) { $0.formUnion($1) }
            
        case .set:
            return Set(catalogs.sets.keys.map { $0.normalized.lowercased() })
            
        case .block:
            return Set(catalogs.sets.values.compactMap { $0.block?.lowercased() })
            
        case .keyword:
            return Self.getCatalogData(.keywordAbilities)
            
        case .watermark:
            return Self.getCatalogData(.watermarks)
        }
    }
    
    private static func getCatalogData(_ catalogType: Catalog.`Type`) -> Set<String> {
        // TODO: A bit gross here.
        return Set((ScryfallCatalogs.shared.catalog(catalogType) ?? []).map { $0.lowercased() })
    }
}
