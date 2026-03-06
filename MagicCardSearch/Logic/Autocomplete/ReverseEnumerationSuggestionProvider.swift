import Foundation
import FuzzyMatch
import ScryfallKit

struct ReverseEnumerationSuggestion: Equatable, Hashable, Sendable, ScorableSuggestion {
    let polarity: Polarity
    let canonicalFilterName: String
    let value: String
    let valueMatchRange: Range<String.Index>?
    let prefixKind: PrefixKind
    let suggestionLength: Int
}

actor ReverseEnumerationSuggestionProvider {
    private let matcher = FuzzyMatcher()

    func getSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, limit: Int) -> [ReverseEnumerationSuggestion] {
        guard limit > 0,
              case .name(let isExact, let partialTerm) = partial.content,
              !isExact else {
            return []
        }

        let searchTerm = partialTerm.incompleteContent

        guard searchTerm.count >= 2 else {
            return []
        }

        let allCandidates = Self.getAllCandidates(catalogData: catalogData)

        guard !allCandidates.isEmpty else {
            return []
        }

        let matched = matcher.matches(allCandidates.map(\.0), against: searchTerm).map(\.candidate)

        return Array(
            matched.lazy
                .flatMap { value in
                    guard let filters = allCandidates.first(where: { $0.0 == value })?.1 else {
                        return [ReverseEnumerationSuggestion]()
                    }
                    let range = value.range(of: searchTerm, options: .caseInsensitive)
                    return filters.map { filter in
                        ReverseEnumerationSuggestion(
                            polarity: partial.polarity,
                            canonicalFilterName: filter.canonicalName,
                            value: value,
                            valueMatchRange: range,
                            prefixKind: value.range(of: searchTerm, options: [.caseInsensitive, .anchored]) == nil ? .none : .effective,
                            suggestionLength: value.count,
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

            for value in enumerationValues.all(sorted: .alphabetically) {
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
