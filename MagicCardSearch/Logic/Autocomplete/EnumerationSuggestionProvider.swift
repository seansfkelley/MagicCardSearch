//
//  EnumerationSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
import ScryfallKit
import Logging

struct EnumerationSuggestion: Equatable {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
}

private enum CacheKey: Hashable {
    case type
    case set
    case block
    case keyword
    case watermark
}

private let logger = Logger(label: "EnumerationSuggestionProvider")

@MainActor
struct EnumerationSuggestionProvider {
    private static let shared = MemoryCache<CacheKey, [String]>(expiration: .never)
    
    func getSuggestions(for searchTerm: String, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [EnumerationSuggestion] {
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
        
        let options: [String]
        if let cacheKey = Self.cacheKey(for: filterType.canonicalName) {
            options = Self.getOptionsFromCache(for: cacheKey)
        } else if let staticOptions = filterType.enumerationValues {
            options = staticOptions
        } else {
            return []
        }
        
        let comparison = Comparison(rawValue: String(comparisonOperator))
        guard let comparison else {
            // If this fires, there's an error in the regex or something, but not a user error.
            logger.warning("comparison was unexpectedly nil")
            return []
        }
        
        let trimmedValue = value.trimmingCharacters(in: .whitespaces)
        
        // n.b. we assume options are sorted by whatever the default priority is, but don't care
        // what it is.
        return Array(options
            .lazy
            .map { option in
                if negated.isEmpty {
                    SearchFilter.basic(.keyValue(filterTypeName.lowercased(), comparison, option))
                } else {
                    SearchFilter.negated(.keyValue(filterTypeName.lowercased(), comparison, option))
                }
            }
            .filter { !excludedFilters.contains($0) }
            .compactMap { filter in
                if trimmedValue.isEmpty {
                    return EnumerationSuggestion(filter: filter, matchRange: nil)
                }
                
                let filterString = filter.queryStringWithEditingRange.0
                if let range = filterString.range(of: trimmedValue, options: .caseInsensitive) {
                    return EnumerationSuggestion(filter: filter, matchRange: range)
                }
                
                return nil
            }
            .prefix(limit)
        )
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
    
    private static func getOptionsFromCache(for key: CacheKey) -> [String] {
        if let options = shared[key] {
            return options
        } else {
            shared[key] = fetchOptions(for: key)
            return shared[key]!
        }
    }
    
    private static func fetchOptions(for key: CacheKey) -> [String] {
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
            ]
            .reduce([], (+))
            .map { $0.lowercased() }
            .sorted()
            
        case .set:
            return catalogs
                .sets
                .values
                .flatMap { [$0.code, $0.name] }
                .map { $0.lowercased().replacing(/[^a-z0-9]/, with: "") }
                .sorted()
            
        case .block:
            return catalogs
                .sets
                .values
                .compactMap { $0.block?.lowercased().replacing(/[^a-z0-9]/, with: "") }
                .sorted()
            
        case .keyword:
            return Self.getCatalogData(.keywordAbilities)
            
        case .watermark:
            return Self.getCatalogData(.watermarks)
        }
    }
    
    private static func getCatalogData(_ catalogType: Catalog.`Type`) -> [String] {
        // TODO: A bit gross here.
        return (ScryfallCatalogs.shared.catalog(catalogType) ?? []).map { $0.lowercased() }.sorted()
    }
}
