import Foundation
import ScryfallKit

struct EnumerationSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let filter: FilterTerm
    let matchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

struct EnumerationCatalogData: Sendable {
    let catalogs: [Catalog.`Type`: [String]]
    let sets: [SetCode: MTGSet]?
    let artTags: [String]?
    let oracleTags: [String]?

    @MainActor
    init(scryfallCatalogs: ScryfallCatalogs) {
        typealias CatalogType = Catalog.`Type`

        var catalogs = [CatalogType: [String]]()
        for type in CatalogType.allCases {
            if let data = scryfallCatalogs[type] {
                catalogs[type] = data
            }
        }
        self.catalogs = catalogs
        self.sets = scryfallCatalogs.sets
        self.artTags = scryfallCatalogs.artTags
        self.oracleTags = scryfallCatalogs.oracleTags
    }

    func combined(_ catalogTypes: Catalog.`Type`...) -> [String]? {
        var result: [String] = []
        for type in catalogTypes {
            guard let data = catalogs[type] else {
                return nil
            }
            result.append(contentsOf: data)
        }
        return result
    }
}

actor EnumerationSuggestionProvider {
    private var matchers = [String: CachingFuzzyMatcher]()

    func getSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, excluding excludedFilters: Set<FilterQuery<FilterTerm>>, limit: Int) -> [EnumerationSuggestion] {
        guard limit > 0,
              case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
              let comparison = partialComparison.toComplete(),
              let filterType = scryfallFilterByType[filterTypeName.lowercased()] else {
            return []
        }

        let allCandidates = if let dynamicOptions = getDynamicOptions(for: filterType, from: catalogData) {
            dynamicOptions
        } else if let staticOptions = filterType.enumerationValues {
            Array(staticOptions.all(sorted: .alphabetically))
        } else {
            [String]()
        }

        guard !allCandidates.isEmpty else {
            return []
        }

        let value = partialValue.incompleteContent

        let matched: [String]
        if value.isEmpty {
            matched = allCandidates.sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        } else {
            let matcher = matchers[filterType.canonicalName] ?? {
                let newMatcher = CachingFuzzyMatcher(countLimit: 100)
                matchers[filterType.canonicalName] = newMatcher
                return newMatcher
            }()
            matched = matcher.match(value, in: allCandidates).map(\.0)
        }

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

    // MARK: - Catalog Options

    private func getDynamicOptions(for filter: ScryfallFilterType, from catalogData: EnumerationCatalogData) -> [String]? {
        switch filter.canonicalName {
        case "type":
            catalogData.combined(
                .supertypes,
                .cardTypes,
                .artifactTypes,
                .battleTypes,
                .creatureTypes,
                .enchantmentTypes,
                .landTypes,
                .planeswalkerTypes,
                .spellTypes,
            )
        case "set":
            catalogData.sets.map {
                $0.values
                    .filter { !AutocompleteConstants.ignoredSetTypes.contains($0.setType) }
                    .flatMap { [$0.code.uppercased(), $0.name] }
                    .map { $0.replacing(/[^a-zA-Z0-9 ]/, with: "") }
            }
        case "block":
            catalogData.sets.map {
                $0.values
                    .filter { !AutocompleteConstants.ignoredSetTypes.contains($0.setType) }
                    .compactMap { $0.block?.replacing(/[^a-zA-Z0-9 ]/, with: "") }
                    .uniqued()
            }
        case "keyword":
            catalogData.catalogs[.keywordAbilities].map { $0.map { $0.lowercased() } }
        case "watermark":
            catalogData.catalogs[.watermarks]
        case "artist":
            catalogData.catalogs[.artistNames]
        case "art":
            catalogData.artTags
        case "function":
            catalogData.oracleTags
        default:
            nil
        }
    }
}
