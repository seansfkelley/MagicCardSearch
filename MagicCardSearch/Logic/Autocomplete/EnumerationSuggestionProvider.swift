import Foundation
import FuzzyMatch
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
    private let matcher = FuzzyMatcher()

    func getSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, excluding excludedFilters: Set<FilterQuery<FilterTerm>>, searchTerm: String, limit: Int) -> [Suggestion2] {
        guard limit > 0,
              case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
              let comparison = partialComparison.toComplete(),
              let filterType = scryfallFilterByType[filterTypeName.lowercased()] else {
            return []
        }

        let allCandidates = if let dynamicOptions = getDynamicOptions(for: filterType, from: catalogData) {
            dynamicOptions
        } else if let staticOptions = filterType.enumerationValues {
            staticOptions
        } else {
            [String]()
        }

        guard !allCandidates.isEmpty else {
            return []
        }

        let value = partialValue.incompleteContent

        let matched: [(String, Double)]
        if value.isEmpty {
            matched = allCandidates.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { ($0, 0) }
        } else {
            matched = matcher.matches(allCandidates, against: value).map { ($0.candidate, $0.match.score) }
        }

        let allResults = matched.map { candidate, score in
            let filter = FilterTerm.basic(partial.polarity, filterTypeName.lowercased(), comparison, candidate)
            return Suggestion2(
                source: .enumeration,
                content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
                score: score,
            )
        }

        return Array(allResults
            .filter {
                if case .filter(let highlighted) = $0.content {
                    !excludedFilters.contains(highlighted.value)
                } else {
                    true
                }
            }
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
