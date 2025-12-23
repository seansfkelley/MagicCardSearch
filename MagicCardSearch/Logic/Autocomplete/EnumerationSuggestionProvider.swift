//
//  EnumerationSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-11.
//
import Foundation
import ScryfallKit
import Logging
import Algorithms

struct EnumerationSuggestion: Equatable, Sendable, ScorableSuggestion {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let isPrefix: Bool
    let suggestionLength: Int
}

private enum CacheKey: Hashable {
    case type
    case subtype
    case set
    case block
    case keyword
    case watermark
}

private let logger = Logger(label: "EnumerationSuggestionProvider")

@MainActor
struct EnumerationSuggestionProvider {
    private static let shared = MemoryCache<CacheKey, IndexedEnumerationValues>(expiration: .never)

    func getSuggestions(for partial: PartialSearchFilter, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [EnumerationSuggestion] {
        guard limit > 0 else {
            return []
        }
        
        guard case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content else {
            return []
        }
        
        guard let comparison = partialComparison.toComplete() else {
            return []
        }
        
        guard let filterType = scryfallFilterByType[filterTypeName.lowercased()] else {
            return []
        }
        
        let value = partialValue.incompleteContent
        
        let matchingOpts: any Sequence<(String, Bool)>
        if filterType.canonicalName == "type" {
            let typeOptions = Self.getOptionsFromCache(for: .type)
            let subtypeOptions = Self.getOptionsFromCache(for: .subtype)
            
            let typeMatches = matchingOptions(from: typeOptions, searchTerm: value)
            let subtypeMatches = matchingOptions(from: subtypeOptions, searchTerm: value)
            
            matchingOpts = chain(AnySequence(typeMatches), AnySequence(subtypeMatches))
        } else {
            let options: IndexedEnumerationValues
            if let cacheKey = Self.cacheKey(for: filterType.canonicalName) {
                options = Self.getOptionsFromCache(for: cacheKey)
            } else if let staticOptions = filterType.enumerationValues {
                options = staticOptions
            } else {
                return []
            }
            
            matchingOpts = matchingOptions(from: options, searchTerm: value)
        }
        
        return Array(matchingOpts
            .map {
                (
                    SearchFilter.Basic(partial.negated, filterTypeName.lowercased(), comparison, $0.0),
                    $0.1,
                )
            }
            .filter { !excludedFilters.contains(.basic($0.0)) }
            .map { args in
                let (filter, isPrefix) = args
                let range = value.isEmpty ? nil : filter.description.range(of: value, options: .caseInsensitive)

                return EnumerationSuggestion(
                    filter: .basic(filter),
                    matchRange: range,
                    isPrefix: isPrefix,
                    suggestionLength: filter.query.count,
                )
            }
            .prefix(limit)
        )
    }
    
    private func matchingOptions(from options: IndexedEnumerationValues, searchTerm: String) -> any Sequence<(String, Bool)> {
        if searchTerm.isEmpty {
            // TODO: Would true produce better results?
            return options.sortedAlphabetically.lazy.map { ($0, false) }
        }
        
        let lowerBound = options.sortedAlphabetically.partitioningIndex { element in
            element.compare(searchTerm, options: [.caseInsensitive]) != .orderedAscending
        }
        
        let upperBound = options.sortedAlphabetically[lowerBound...].partitioningIndex { element in
            element.range(of: searchTerm, options: [.anchored, .caseInsensitive]) == nil
        }
        
        let prefixMatches = options.sortedAlphabetically[lowerBound..<upperBound]
        
        var prefixSet: Set<String>?
        let substringMatches = options.sortedByLength.lazy.filter { option in
            if prefixSet == nil {
                prefixSet = Set(prefixMatches)
            }
            return !prefixSet!.contains(option) && option.range(of: searchTerm, options: .caseInsensitive) != nil
        }
        
        return chain(prefixMatches.lazy.map { ($0, true) }, substringMatches.map { ($0, false) })
    }
    
    // MARK: - Cache Management
    
    private static func cacheKey(for canonicalName: String) -> CacheKey? {
        switch canonicalName {
        case "set": .set
        case "block": .block
        case "keyword": .keyword
        case "watermark": .watermark
        default: nil
        }
    }
    
    private static func getOptionsFromCache(for key: CacheKey) -> IndexedEnumerationValues {
        if let options = shared[key] {
            return options
        } else {
            shared[key] = fetchOptions(for: key)
            return shared[key]!
        }
    }
    
    private static func fetchOptions(for key: CacheKey) -> IndexedEnumerationValues {
        let catalogs = ScryfallCatalogs.shared
        
        switch key {
        case .type:
            return IndexedEnumerationValues(
                [
                    Self.getCatalogData(.supertypes),
                    Self.getCatalogData(.cardTypes),
                ]
                .reduce([], (+))
                .map { $0.lowercased() }
            )
            
        case .subtype:
            return IndexedEnumerationValues(
                [
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
            )
            
        case .set:
            return IndexedEnumerationValues(
                catalogs
                    .sets
                    .values
                    .flatMap { [$0.code, $0.name] }
                    .map { $0.lowercased().replacing(/[^a-z0-9 ]/, with: "") }
            )
            
        case .block:
            return IndexedEnumerationValues(
                catalogs
                    .sets
                    .values
                    .compactMap { $0.block?.lowercased().replacing(/[^a-z0-9 ]/, with: "") }
            )
            
        case .keyword:
            return IndexedEnumerationValues(Self.getCatalogData(.keywordAbilities).map { $0.lowercased() })
            
        case .watermark:
            return IndexedEnumerationValues(Self.getCatalogData(.watermarks).map { $0.lowercased() })
        }
    }
    
    private static func getCatalogData(_ catalogType: Catalog.`Type`) -> [String] {
        Array(ScryfallCatalogs.shared.catalog(catalogType) ?? [])
    }
}
