import Foundation
import ScryfallKit
import OSLog
import Algorithms

struct EnumerationSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: FilterTerm
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
    case artist
    case artTag
    case oracleTag
}

// These are really noisy in the search results and I can't imagine anyone ever wants them.
private let ignoredSetTypes: Set<MTGSet.Kind> = [
    .token,
    .promo,
]

private let logger = Logger(subsystem: "MagicCardSearch", category: "EnumerationSuggestionProvider")

@MainActor
struct EnumerationSuggestionProvider {
    private let cache = MemoryCache<CacheKey, IndexedEnumerationValues<String>>()

    let scryfallCatalogs: ScryfallCatalogs

    func getSuggestions(for partial: PartialFilterTerm, excluding excludedFilters: Set<FilterQuery<FilterTerm>>, limit: Int) -> [EnumerationSuggestion] {
        guard limit > 0,
              case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
              let comparison = partialComparison.toComplete(),
              let filterType = scryfallFilterByType[filterTypeName.lowercased()] else {
            return []
        }
        
        let value = partialValue.incompleteContent
        
        let matchingOpts: any Sequence<(String, Bool)>
        if filterType.canonicalName == "type" {
            let typeOptions = getCachedOptions(for: .type)
            let subtypeOptions = getCachedOptions(for: .subtype)

            let typeMatches = typeOptions.map { matchOptions($0, against: value) } ?? []
            let subtypeMatches = subtypeOptions.map { matchOptions($0, against: value) } ?? []

            matchingOpts = chain(
                AnySequence(typeMatches),
                AnySequence(subtypeMatches),
            )
        } else if let cacheKey = Self.filterCacheKey(for: filterType.canonicalName) {
            matchingOpts = getCachedOptions(for: cacheKey).map {
                matchOptions($0, against: value)
            } ?? []
        } else if let staticOptions = filterType.enumerationValues {
            matchingOpts = matchOptions(staticOptions, against: value)
        } else {
            matchingOpts = []
        }

        return Array(matchingOpts
            .map {
                (
                    FilterTerm.basic(partial.polarity, filterTypeName.lowercased(), comparison, $0.0),
                    $0.1,
                    $0.0.count,
                )
            }
            .filter { !excludedFilters.contains(.term($0.0)) }
            .map { args in
                let (filter, isPrefix, queryLength) = args
                let range = value.isEmpty ? nil : filter.description.range(of: value, options: .caseInsensitive)

                return EnumerationSuggestion(
                    filter: filter,
                    matchRange: range,
                    prefixKind: isPrefix ? (partial.polarity == .negative ? .effective : .actual) : .none,
                    suggestionLength: queryLength,
                )
            }
            .prefix(limit)
        )
    }
    
    private func matchOptions(_ options: IndexedEnumerationValues<String>, against searchTerm: String) -> any Sequence<(String, Bool)> {
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
    
    private static func filterCacheKey(for canonicalName: String) -> CacheKey? {
        switch canonicalName {
        case "set": .set
        case "block": .block
        case "keyword": .keyword
        case "watermark": .watermark
        case "artist": .artist
        case "art": .artTag
        case "function": .oracleTag
        default: nil
        }
    }

    private func getCachedOptions(for key: CacheKey) -> IndexedEnumerationValues<String>? {
        if let value = cache[key] {
            return value
        } else if let value = getOptions(for: key) {
            cache[key] = value
            return value
        } else {
            return nil
        }
    }

    private func getOptions(for key: CacheKey) -> IndexedEnumerationValues<String>? {
        switch key {
        case .type:
            getCatalogData(.supertypes, .cardTypes).map { IndexedEnumerationValues($0) }
        case .subtype:
            getCatalogData(.artifactTypes, .battleTypes, .creatureTypes, .enchantmentTypes, .landTypes, .planeswalkerTypes, .spellTypes).map {
                IndexedEnumerationValues($0)
            }
        case .set:
            scryfallCatalogs.sets.map {
                IndexedEnumerationValues(
                    $0.values
                        .filter { !ignoredSetTypes.contains($0.setType) }
                        .flatMap { [$0.code.uppercased(), $0.name] }
                        .map { $0.replacing(/[^a-zA-Z0-9 ]/, with: "") }
                )
            }
        case .block:
            scryfallCatalogs.sets.map {
                IndexedEnumerationValues(
                    $0.values
                        .filter { !ignoredSetTypes.contains($0.setType) }
                        .compactMap { $0.block?.replacing(/[^a-zA-Z0-9 ]/, with: "") }
                        .uniqued()
                )
            }
        case .keyword:
            getCatalogData(.keywordAbilities).map {
                IndexedEnumerationValues($0.map { $0.lowercased() })
            }
        case .watermark:
            getCatalogData(.watermarks).map { IndexedEnumerationValues($0) }
        case .artist:
            getCatalogData(.artistNames).map { IndexedEnumerationValues($0) }
        case .artTag:
            scryfallCatalogs.artTags.map { IndexedEnumerationValues($0) }
        case .oracleTag:
            scryfallCatalogs.oracleTags.map { IndexedEnumerationValues($0) }
        }
    }

    @MainActor
    private func getCatalogData(_ catalogTypes: Catalog.`Type`...) -> [String]? {
        var combined: [String] = []
        for type in catalogTypes {
            guard let data = scryfallCatalogs[type] else {
                return nil
            }
            combined.append(contentsOf: data)
        }
        return combined
    }
}
