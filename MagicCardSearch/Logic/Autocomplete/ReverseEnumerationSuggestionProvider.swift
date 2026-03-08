import Foundation
import FuzzyMatch
import ScryfallKit

actor ReverseEnumerationSuggestionProvider {
    private let matcher = FuzzyMatcher()

    func getSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String, limit: Int) -> [Suggestion] {
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

        let matchResults = timed("ReverseEnumerationSuggestionProvider fuzzy match") {
            matcher.matches(allCandidates.map(\.0), against: partialSearchTerm)
        }

        return Array(
            matchResults.lazy
                .flatMap { result in
                    guard let filters = allCandidates.first(where: { $0.0 == result.candidate })?.1 else {
                        return [Suggestion]()
                    }
                    return filters.map { filterType in
                        Suggestion(
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

        for filterType in scryfallFilterTypes {
            guard let values = catalogData[filterType] else { continue }
            for value in values {
                valueToFilters[value, default: []].append(filterType)
            }
        }

        return valueToFilters
    }
}
