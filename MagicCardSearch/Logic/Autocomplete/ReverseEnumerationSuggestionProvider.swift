//
//  ReverseEnumerationSuggestionProvider.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-27.
//
import Foundation
import Algorithms
import ScryfallKit

struct ReverseEnumerationSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let negated: Bool
    let canonicalFilterName: String
    let value: String
    let valueMatchRange: Range<String.Index>
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

struct ReverseEnumerationSuggestionProvider {
    private static let cacheLock = NSLock()
    nonisolated(unsafe) private static var cache: CachedIndex = .unloaded

    func getSuggestions(for partial: PartialSearchFilter, excluding excludedFilters: Set<SearchFilter>, limit: Int) -> [ReverseEnumerationSuggestion] {
        guard limit > 0,
                case .name(let isExact, let partialTerm) = partial.content,
                !isExact,
                case .bare(let searchTerm) = partialTerm,
                searchTerm.count >= 2 else {
            return []
        }

        let options = Self.getIndex()

        let prefixMatches = Array(options.matching(prefix: searchTerm, sorted: .byLength))

        var prefixSet: Set<String>?
        let substringMatches = options.matching(anywhere: searchTerm, sorted: .byLength).filter { option in
            if prefixSet == nil {
                prefixSet = Set(prefixMatches.map { $0.value.0 })
            }
            return !prefixSet!.contains(option.value.0)
        }

        return Array(
            chain(
                prefixMatches.lazy.flatMap { match in
                    match.value.1.map { filter in
                        ReverseEnumerationSuggestion(
                            negated: partial.negated,
                            canonicalFilterName: filter.canonicalName,
                            value: match.value.0,
                            valueMatchRange: match.range,
                            prefixKind: .effective,
                            // TODO: Should this count the filter name's length too?
                            suggestionLength: match.value.0.count,
                        )
                    }
                },
                substringMatches.flatMap { match in
                    match.value.1.map { filter in
                        ReverseEnumerationSuggestion(
                            negated: partial.negated,
                            canonicalFilterName: filter.canonicalName,
                            value: match.value.0,
                            valueMatchRange: match.range,
                            prefixKind: .none,
                            // TODO: Should this count the filter name's length too?
                            suggestionLength: match.value.0.count,
                        )
                    }
                },
            )
            .prefix(limit)
        )
    }

    static func getIndex() -> IndexedEnumerationValues<(String, [ScryfallFilterType])> {
        cacheLock.withLock {
            if case .all(let index) = cache {
                return index
            } else if let dynamic = Self.getDynamicIndexMembers() {
                var valueToFilters = Self.getStaticIndexMembers()

                for (key, value) in dynamic {
                    valueToFilters[key, default: []].append(contentsOf: value)
                }

                let index = IndexedEnumerationValues(valueToFilters.map { ($0.key, $0.value) }) { $0.0 }
                cache = .all(index)
                return index
            } else if case .static(let index) = cache {
                return index
            } else {
                let valueToFilters = Self.getStaticIndexMembers()
                let index = IndexedEnumerationValues(valueToFilters.map { ($0.key, $0.value) }) { $0.0 }
                cache = .static(index)
                return index
            }
        }
    }

    fileprivate static func getStaticIndexMembers() -> [String: [ScryfallFilterType]] {
        var valueToFilters: [String: [ScryfallFilterType]] = [:]

        for filterType in scryfallFilterTypes {
            guard let enumerationValues = filterType.enumerationValues else {
                continue
            }

            for value in enumerationValues.all(sorted: .alphabetically) {
                valueToFilters[value, default: []].append(filterType)
            }
        }

        return valueToFilters
    }

    fileprivate static func getDynamicIndexMembers() -> [String: [ScryfallFilterType]]? {
        guard let catalogs = ScryfallCatalogs.sync else { return nil }

        var valueToFilters = [String: [ScryfallFilterType]]()

        func addCatalog(_ types: Catalog.`Type`..., to filter: String) {
            guard let filterType = scryfallFilterByType[filter] else { return }
            for type in types {
                guard let values = catalogs.catalogs[type] else { continue }
                for value in values {
                    valueToFilters[value.lowercased(), default: []].append(filterType)
                }
            }
        }

        addCatalog(.keywordAbilities, to: "keyword")
        addCatalog(.watermarks, to: "watermark")
        addCatalog(.supertypes, .cardTypes, .artifactTypes, .battleTypes, .creatureTypes, .enchantmentTypes, .landTypes, .planeswalkerTypes, .spellTypes, to: "type")

        if let setFilter = scryfallFilterByType["set"] {
            for set in catalogs.sets.values {
                valueToFilters[set.code.lowercased().replacing(/[^a-z0-9 ]/, with: ""), default: []].append(setFilter)
                valueToFilters[set.name.lowercased().replacing(/[^a-z0-9 ]/, with: ""), default: []].append(setFilter)
            }
        }

        if let blockFilter = scryfallFilterByType["block"] {
            for block in catalogs.sets.values.compactMap({ $0.block?.lowercased().replacing(/[^a-z0-9 ]/, with: "") }) {
                valueToFilters[block, default: []].append(blockFilter)
            }
        }

        return valueToFilters
    }
}

private enum CachedIndex {
    case unloaded
    case `static`(IndexedEnumerationValues<(String, [ScryfallFilterType])>)
    case all(IndexedEnumerationValues<(String, [ScryfallFilterType])>)
}
