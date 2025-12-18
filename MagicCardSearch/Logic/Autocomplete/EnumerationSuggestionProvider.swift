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
        
        // Determine the options to use - either from cache or from static enumeration
        let options: Set<String>
        if let cacheKey = Self.cacheKey(for: filterType.canonicalName) {
            options = Self.getOptionsFromCache(for: cacheKey)
        } else if let staticOptions = filterType.enumerationValues {
            options = staticOptions
        } else {
            return []
        }
        
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
    
    /// Maps canonical filter names to cache keys
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
    
    /// Retrieves options from cache, fetching from Scryfall if needed
    private static func getOptionsFromCache(for key: CacheKey) -> Set<String> {
        do {
            return try shared.get(forKey: key) {
                fetchOptions(for: key)
            }
        } catch {
            // If fetching fails, return empty set
            return []
        }
    }
    
    /// Fetches options from Scryfall catalogs based on cache key
    private static func fetchOptions(for key: CacheKey) -> Set<String> {
        let catalogs = ScryfallCatalogs.shared
        
        switch key {
        case .type:
            // Combine multiple type catalogs
            return Self.getCatalogData(.supertypes)
                .union(Self.getCatalogData(.cardTypes))
                .union(Self.getCatalogData(.artifactTypes))
                .union(Self.getCatalogData(.battleTypes))
                .union(Self.getCatalogData(.creatureTypes))
                .union(Self.getCatalogData(.enchantmentTypes))
                .union(Self.getCatalogData(.landTypes))
                .union(Self.getCatalogData(.planeswalkerTypes))
                .union(Self.getCatalogData(.spellTypes))
            
        case .set:
            // Use set codes from the cached sets
            return Set(catalogs.sets.keys.map { $0.normalized.lowercased() })
            
        case .block:
            // Extract unique block names from sets
            return Set(catalogs.sets.values.compactMap { $0.block?.lowercased() })
            
        case .keyword:
            // Combine keyword abilities and actions
            return Self.getCatalogData(.keywordAbilities)
                .union(Self.getCatalogData(.keywordActions))
            
        case .watermark:
            return Self.getCatalogData(.watermarks)
        }
    }
    
    /// Helper to get catalog data from ScryfallCatalogs' string cache
    private static func getCatalogData(_ catalogType: Catalog.`Type`) -> Set<String> {
        return ScryfallCatalogs.shared.getCatalog(catalogType) ?? []
    }
}
