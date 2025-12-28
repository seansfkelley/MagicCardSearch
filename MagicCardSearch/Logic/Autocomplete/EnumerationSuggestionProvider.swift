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

struct EnumerationSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: SearchFilter
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
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

struct EnumerationSuggestionProvider {
    private static let shared = MemoryCache<CacheKey, IndexedEnumerationValues<String>>(expiration: .never)

    func getSuggestions(for partial: PartialSearchFilter, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [EnumerationSuggestion] {
        guard limit > 0,
              case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
              let comparison = partialComparison.toComplete(),
              let filterType = scryfallFilterByType[filterTypeName.lowercased()] else {
            return []
        }
        
        let value = partialValue.incompleteContent
        
        let matchingOpts: any Sequence<(String, Bool)>
        if filterType.canonicalName == "type" {
            let typeOptions = Self.getOptionsFromCache(for: .type)
            let subtypeOptions = Self.getOptionsFromCache(for: .subtype)
            
            let typeMatches = typeOptions.map { matchingOptions(from: $0, searchTerm: value) } ?? []
            let subtypeMatches = subtypeOptions.map { matchingOptions(from: $0, searchTerm: value) } ?? []

            matchingOpts = chain(
                AnySequence(typeMatches),
                AnySequence(subtypeMatches),
            )
        } else if let cacheKey = Self.cacheKey(for: filterType.canonicalName) {
            matchingOpts = Self.getOptionsFromCache(for: cacheKey).map {
                matchingOptions(from: $0, searchTerm: value)
            } ?? []
        } else if let staticOptions = filterType.enumerationValues {
            matchingOpts = matchingOptions(from: staticOptions, searchTerm: value)
        } else {
            matchingOpts = []
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
                    prefixKind: isPrefix ? (partial.negated ? .effective : .actual) : .none,
                    suggestionLength: filter.query.count,
                )
            }
            .prefix(limit)
        )
    }
    
    private func matchingOptions(from options: IndexedEnumerationValues<String>, searchTerm: String) -> any Sequence<(String, Bool)> {
        if searchTerm.isEmpty {
            // TODO: Would true produce better results?
            return options.all(sorted: .alphabetically).map { ($0, false) }
        }

        let prefixMatches = Array(options.matching(prefix: searchTerm, sorted: .byLength))

        var prefixSet: Set<String>?
        let substringMatches = options.matching(anywhere: searchTerm, sorted: .byLength).filter { option in
            if prefixSet == nil {
                prefixSet = Set(prefixMatches.map { $0.value })
            }
            return !prefixSet!.contains(option.value)
        }
        
        return chain(prefixMatches.lazy.map { ($0.value, true) }, substringMatches.map { ($0.value, false) })
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
    
    private static func getOptionsFromCache(for key: CacheKey) -> IndexedEnumerationValues<String>? {
        if let options = shared[key] {
            return options
        } else if let options = fetchOptions(for: key) {
            shared[key] = options
            return options
        } else {
            return nil
        }
    }
    
    private static func fetchOptions(for key: CacheKey) -> IndexedEnumerationValues<String>? {
        switch key {
        case .type:
            Self.getCatalogData(.supertypes, .cardTypes).map {
                IndexedEnumerationValues($0.map { $0.lowercased() })
            }
        case .subtype:
            Self.getCatalogData(.artifactTypes, .battleTypes, .creatureTypes, .enchantmentTypes, .landTypes, .planeswalkerTypes, .spellTypes).map {
                IndexedEnumerationValues($0.map { $0.lowercased() })
            }
            
        case .set:
            ScryfallCatalogs.sync.map {
                IndexedEnumerationValues(
                    $0.sets.values
                        .flatMap { [$0.code, $0.name] }
                        .map { $0.lowercased().replacing(/[^a-z0-9 ]/, with: "") }
                )
            }
            
        case .block:
            ScryfallCatalogs.sync.map {
                IndexedEnumerationValues(
                    $0.sets.values.compactMap {
                        $0.block?.lowercased().replacing(/[^a-z0-9 ]/, with: "")
                    }
                )
            }

        case .keyword:
            Self.getCatalogData(.keywordAbilities).map {
                IndexedEnumerationValues($0.map { $0.lowercased() })
            }

        case .watermark:
            Self.getCatalogData(.watermarks).map {
                IndexedEnumerationValues($0.map { $0.lowercased() })
            }
        }
    }
    
    private static func getCatalogData(_ catalogTypes: Catalog.`Type`...) -> [String]? {
        guard let catalogs = ScryfallCatalogs.sync.map({ $0.catalogs }) else { return nil }

        var combined: [String] = []
        for type in catalogTypes {
            guard let data = catalogs[type] else {
                return nil
            }
            combined.append(contentsOf: data)
        }
        return combined
    }
}
