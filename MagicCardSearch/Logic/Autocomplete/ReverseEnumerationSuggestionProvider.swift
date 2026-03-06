import Foundation
import FuzzyMatch
import ScryfallKit

actor ReverseEnumerationSuggestionProvider {
    private let matcher = FuzzyMatcher()

    func getSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String, limit: Int) -> [Suggestion2] {
        guard limit > 0,
              case .name(let isExact, let partialTerm) = partial.content,
              !isExact else {
            return []
        }

        let partialSearchTerm = partialTerm.incompleteContent

        guard partialSearchTerm.count >= 2 else {
            return []
        }

        let allCandidates = Self.getAllCandidates(catalogData: catalogData)

        guard !allCandidates.isEmpty else {
            return []
        }

        let matchResults = matcher.matches(allCandidates.map(\.0), against: partialSearchTerm)

        return Array(
            matchResults.lazy
                .flatMap { result in
                    guard let filters = allCandidates.first(where: { $0.0 == result.candidate })?.1 else {
                        return [Suggestion2]()
                    }
                    return filters.map { filterType in
                        Suggestion2(
                            source: .reverseEnumeration,
                            content: .filterParts(partial.polarity, filterType, WithHighlightedString(value: result.candidate, string: result.candidate, searchTerm: searchTerm)),
                            score: result.match.score,
                        )
                    }
                }
                .prefix(limit)
        )
    }

    private static func getAllCandidates(catalogData: EnumerationCatalogData) -> [(String, [ScryfallFilterType])] {
        var valueToFilters = getStaticIndexMembers()

        for (key, value) in getDynamicIndexMembers(catalogData: catalogData) {
            valueToFilters[key, default: []].append(contentsOf: value)
        }

        return valueToFilters.map { ($0.key, $0.value) }
    }

    private static func getStaticIndexMembers() -> [String: [ScryfallFilterType]] {
        var valueToFilters: [String: [ScryfallFilterType]] = [:]

        for filterType in scryfallFilterTypes {
            guard let enumerationValues = filterType.enumerationValues else {
                continue
            }

            for value in enumerationValues {
                valueToFilters[value, default: []].append(filterType)
            }
        }

        return valueToFilters
    }

    private static func getDynamicIndexMembers(catalogData: EnumerationCatalogData) -> [String: [ScryfallFilterType]] {
        var valueToFilters = [String: [ScryfallFilterType]]()

        func addCatalogs(_ types: Catalog.`Type`..., to filter: String, lowercased: Bool = false) {
            guard let filterType = scryfallFilterByType[filter] else { return }
            for type in types {
                guard let values = catalogData.catalogs[type] else { continue }
                for value in values {
                    valueToFilters[lowercased ? value.lowercased() : value, default: []].append(filterType)
                }
            }
        }

        addCatalogs(.artistNames, to: "artist")
        addCatalogs(.keywordAbilities, to: "keyword", lowercased: true)
        addCatalogs(.watermarks, to: "watermark")
        addCatalogs(.supertypes, .cardTypes, .artifactTypes, .battleTypes, .creatureTypes, .enchantmentTypes, .landTypes, .planeswalkerTypes, .spellTypes, to: "type")

        if let sets = catalogData.sets?.values.filter({ !AutocompleteConstants.ignoredSetTypes.contains($0.setType) }) {
            if let setFilter = scryfallFilterByType["set"] {
                for set in sets {
                    valueToFilters[set.code.uppercased().replacing(/[^a-zA-Z0-9 ]/, with: ""), default: []].append(setFilter)
                    // n.b. Scryfall does NOT want any other characters like colons (e.g. "Avatar: the
                    // Last Airbender") as it will not match anything.
                    valueToFilters[set.name.replacing(/[^a-zA-Z0-9 ]/, with: ""), default: []].append(setFilter)
                }
            }

            if let blockFilter = scryfallFilterByType["block"] {
                // n.b. Scryfall does NOT want any other characters like colons (e.g. "Avatar: the
                // Last Airbender") as it will not match anything.
                for block in sets.compactMap({ $0.block?.replacing(/[^a-zA-Z0-9 ]/, with: "") }).uniqued() {
                    valueToFilters[block, default: []].append(blockFilter)
                }
            }
        }

        return valueToFilters
    }
}
