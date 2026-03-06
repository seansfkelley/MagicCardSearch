import Foundation
import ScryfallKit
import OSLog
import Algorithms
import Cache
import FuzzyMatch

struct EnumerationSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: FilterTerm
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

struct EnumerationCatalogData: Sendable {
    let catalogs: [String: [String]]
    let sets: [SetCode: MTGSet]?
    let artTags: [String]?
    let oracleTags: [String]?

    init(catalogs: [String: [String]], sets: [SetCode: MTGSet]?, artTags: [String]?, oracleTags: [String]?) {
        self.catalogs = catalogs
        self.sets = sets
        self.artTags = artTags
        self.oracleTags = oracleTags
    }

    @MainActor
    init(scryfallCatalogs: ScryfallCatalogs) {
        typealias CatalogType = Catalog.`Type`
        var catalogs = [String: [String]]()
        for type in CatalogType.allCases {
            if let data = scryfallCatalogs[type] {
                catalogs[type.rawValue] = data
            }
        }
        self.catalogs = catalogs
        self.sets = scryfallCatalogs.sets
        self.artTags = scryfallCatalogs.artTags
        self.oracleTags = scryfallCatalogs.oracleTags
    }

    subscript(catalogType: Catalog.`Type`) -> [String]? {
        catalogs[catalogType.rawValue]
    }
}

private enum SourceCacheKey: Hashable {
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

private struct QueryCacheKey: Hashable {
    let filterCanonicalName: String
    let normalizedQuery: String
}

private let logger = Logger(subsystem: "MagicCardSearch", category: "EnumerationSuggestionProvider")

private func normalizeForCache(_ string: String) -> String {
    string.lowercased().replacing(/[^a-z]/, with: "")
}

actor EnumerationSuggestionProvider {
    private let sourceCache = StrongMemoryStorage<SourceCacheKey, [String]>(
        config: .init(expiry: .never, countLimit: 100),
    )

    private let queryCache = StrongMemoryStorage<QueryCacheKey, [String]>(
        config: .init(expiry: .never, countLimit: 100),
    )

    func getSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, excluding excludedFilters: Set<FilterQuery<FilterTerm>>, limit: Int) -> [EnumerationSuggestion] {
        guard limit > 0,
              case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
              let comparison = partialComparison.toComplete(),
              let filterType = scryfallFilterByType[filterTypeName.lowercased()] else {
            return []
        }

        let value = partialValue.incompleteContent
        let normalizedValue = normalizeForCache(value)

        // Find all source candidates for this filter type
        let allCandidates: [String]
        if filterType.canonicalName == "type" {
            let typeOptions = getCachedOptions(for: .type, catalogData: catalogData) ?? []
            let subtypeOptions = getCachedOptions(for: .subtype, catalogData: catalogData) ?? []
            allCandidates = typeOptions + subtypeOptions
        } else if let sourceCacheKey = Self.filterCacheKey(for: filterType.canonicalName) {
            allCandidates = getCachedOptions(for: sourceCacheKey, catalogData: catalogData) ?? []
        } else if let staticOptions = filterType.enumerationValues {
            allCandidates = Array(staticOptions.all(sorted: .alphabetically))
        } else {
            allCandidates = []
        }

        // Use query cache prefix narrowing to find the best candidate set
        let candidates: [String]
        let cacheKeys = queryCache.allKeys.filter { $0.filterCanonicalName == filterType.canonicalName }
        let bestPrefix = cacheKeys
            .filter { normalizedValue.hasPrefix($0.normalizedQuery) }
            .max(by: { $0.normalizedQuery.count < $1.normalizedQuery.count })

        if let bestPrefix, let cached = try? queryCache.entry(forKey: bestPrefix).object {
            candidates = cached
        } else {
            candidates = allCandidates
        }

        let matched: [String]
        if value.isEmpty {
            matched = candidates.sorted(by: { $0.localizedStandardCompare($1) == .orderedAscending })
        } else {
            let matcher = FuzzyMatcher()
            let query = matcher.prepare(value)
            var buffer = matcher.makeBuffer()

            let start = ContinuousClock().now
            let results: [(String, ScoredMatch)] = candidates.compactMap { candidate -> (String, ScoredMatch)? in
                guard let match = matcher.score(candidate, against: query, buffer: &buffer) else {
                    return nil
                }
                return (candidate, match)
            }
            let elapsed = ContinuousClock().now - start
            logger.info("Fuzzy match over \(candidates.count) candidates took \(elapsed)")

            let start2 = ContinuousClock().now
            let sorted = results.sorted { $0.1.score > $1.1.score }
            let elapsed2 = ContinuousClock().now - start2
            logger.info("Sorting \(results.count) results took \(elapsed2)")

            matched = sorted.map(\.0)
        }

        let cacheKey = QueryCacheKey(filterCanonicalName: filterType.canonicalName, normalizedQuery: normalizedValue)
        queryCache.setObject(matched, forKey: cacheKey)

        let allResults = matched.map { candidate in
            let filter = FilterTerm.basic(partial.polarity, filterTypeName.lowercased(), comparison, candidate)
            let range = value.isEmpty ? nil : filter.description.range(of: value, options: .caseInsensitive)

            return EnumerationSuggestion(
                filter: filter,
                matchRange: range,
                prefixKind: candidate.range(of: value, options: [.caseInsensitive, .anchored]) == nil ? .none : (partial.polarity == .negative ? .effective : .actual),
                suggestionLength: candidate.count,
            )
        }

        return Array(allResults
            .filter { !excludedFilters.contains(.term($0.filter)) }
            .prefix(limit)
        )
    }

    // MARK: - Source Cache Management

    private static func filterCacheKey(for canonicalName: String) -> SourceCacheKey? {
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

    private func getCachedOptions(for key: SourceCacheKey, catalogData: EnumerationCatalogData) -> [String]? {
        if let value = try? sourceCache.entry(forKey: key) {
            return value.object
        } else if let value = getOptions(for: key, catalogData: catalogData) {
            sourceCache.setObject(value, forKey: key)
            return value
        } else {
            return nil
        }
    }

    private func getOptions(for key: SourceCacheKey, catalogData: EnumerationCatalogData) -> [String]? {
        switch key {
        case .type:
            getCatalogData(catalogData, .supertypes, .cardTypes)
        case .subtype:
            getCatalogData(catalogData, .artifactTypes, .battleTypes, .creatureTypes, .enchantmentTypes, .landTypes, .planeswalkerTypes, .spellTypes)
        case .set:
            catalogData.sets.map {
                $0.values
                    .filter { !AutocompleteConstants.ignoredSetTypes.contains($0.setType) }
                    .flatMap { [$0.code.uppercased(), $0.name] }
                    .map { $0.replacing(/[^a-zA-Z0-9 ]/, with: "") }
            }
        case .block:
            catalogData.sets.map {
                $0.values
                    .filter { !AutocompleteConstants.ignoredSetTypes.contains($0.setType) }
                    .compactMap { $0.block?.replacing(/[^a-zA-Z0-9 ]/, with: "") }
                    .uniqued()
            }
        case .keyword:
            getCatalogData(catalogData, .keywordAbilities).map { $0.map { $0.lowercased() } }
        case .watermark:
            getCatalogData(catalogData, .watermarks)
        case .artist:
            getCatalogData(catalogData, .artistNames)
        case .artTag:
            catalogData.artTags
        case .oracleTag:
            catalogData.oracleTags
        }
    }

    private func getCatalogData(_ catalogData: EnumerationCatalogData, _ catalogTypes: Catalog.`Type`...) -> [String]? {
        var combined: [String] = []
        for type in catalogTypes {
            guard let data = catalogData[type] else {
                return nil
            }
            combined.append(contentsOf: data)
        }
        return combined
    }
}
