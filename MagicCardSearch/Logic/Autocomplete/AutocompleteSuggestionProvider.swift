import Foundation
import SQLiteData
import FuzzyMatch
import ScryfallKit

struct Suggestion {
    enum Source {
        case pinnedFilter, historyFilter, filterType, enumeration, reverseEnumeration, name
    }

    enum Content: Hashable {
        case filter(WithHighlightedString<FilterQuery<FilterTerm>>)
        case filterType(WithHighlightedString<FilterTypeSuggestion>)
        case filterParts(Polarity, ScryfallFilterType, WithHighlightedString<String>)
    }

    let source: Source
    let content: Content
    let score: Double

    var biasedScore: Double {
        let bias: Double = switch source {
        case .pinnedFilter: 1
        case .historyFilter: -1
        case .filterType, .enumeration, .reverseEnumeration, .name: 0
        }
        return score + bias
    }
}

struct FilterTypeSuggestion: Hashable, Sendable {
    let polarity: Polarity
    let filterType: ScryfallFilterType
}

@MainActor
class AutocompleteSuggestionProvider {
    private let scryfallCatalogs: ScryfallCatalogs

    @ObservationIgnored @FetchAll private var pinnedFilters: [PinnedFilterEntry]
    @ObservationIgnored @FetchAll(FilterHistoryEntry.order { $0.lastUsedAt.desc() }) private var filterHistoryEntries

    init(scryfallCatalogs: ScryfallCatalogs) {
        self.scryfallCatalogs = scryfallCatalogs
    }

    func getSuggestions(for searchTerm: String, existingFilters: Set<FilterQuery<FilterTerm>>) -> AsyncStream<[Suggestion]> {
        let partial = PartialFilterTerm.from(searchTerm)

        let (stream, continuation) = AsyncStream.makeStream(of: [Suggestion].self)

        let task = Task {
            await withTaskGroup(of: [Suggestion].self) { group in
                let catalogData = EnumerationCatalogData(scryfallCatalogs: self.scryfallCatalogs)

                do {
                    let filters = pinnedFilters
                    group.addTask {
                        pinnedFilterSuggestions(for: partial, from: filters, searchTerm: searchTerm)
                    }
                }
                do {
                    let history = filterHistoryEntries
                    group.addTask {
                        filterHistorySuggestions(for: searchTerm, from: history, limit: 20)
                    }
                }
                group.addTask {
                    filterTypeSuggestions(for: partial, searchTerm: searchTerm, limit: 4)
                }
                group.addTask {
                    reverseEnumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: searchTerm, limit: 20)
                }
                group.addTask {
                    enumerationSuggestions(
                        for: partial,
                        catalogData: catalogData,
                        searchTerm: searchTerm,
                        limit: 40,
                    )
                }
                if let cardNames = self.scryfallCatalogs.cardNames {
                    group.addTask {
                        nameSuggestions(for: partial, in: cardNames, searchTerm: searchTerm, limit: 10)
                    }
                }

                var suggestions: [Suggestion] = []
                for await batch in group {
                    suggestions.append(contentsOf: batch.filter {
                        if case .filter(let highlighted) = $0.content {
                            !existingFilters.contains(highlighted.value)
                        } else if searchTerm.isEmpty {
                            true
                        } else if $0.score < 0.8 {
                            false
                        } else {
                            true
                        }
                    })
                    continuation.yield(sortCombinedSuggestions(suggestions))
                }
                continuation.finish()
            }
        }

        continuation.onTermination = { _ in task.cancel() }

        return stream
    }
}

private func sortCombinedSuggestions(_ suggestions: [Suggestion]) -> [Suggestion] {
    var seen = Set<Suggestion.Content>()
    return suggestions
        .sorted { $0.biasedScore > $1.biasedScore }
        .filter { seen.insert($0.content).inserted }
}

func pinnedFilterSuggestions(for partial: PartialFilterTerm, from pinnedFilters: [PinnedFilterEntry], searchTerm: String) -> [Suggestion] {
    let trimmedSearchTerm = partial.description.trimmingCharacters(in: .whitespaces)

    let matcher = FuzzyMatcher()
    let query = matcher.prepare(trimmedSearchTerm)
    var buffer = matcher.makeBuffer()

    return pinnedFilters
        .compactMap { row in
            let filterText = row.filter.description

            if trimmedSearchTerm.isEmpty {
                return Suggestion(
                    source: .pinnedFilter,
                    content: .filter(WithHighlightedString(value: row.filter, string: filterText, searchTerm: searchTerm)),
                    score: 0,
                )
            }

            if let match = matcher.score(filterText, against: query, buffer: &buffer) {
                return Suggestion(
                    source: .pinnedFilter,
                    content: .filter(WithHighlightedString(value: row.filter, string: filterText, searchTerm: searchTerm)),
                    score: match.score,
                )
            }

            return nil
        }
}

func filterHistorySuggestions(for searchTerm: String, from filterHistoryEntries: [FilterHistoryEntry], limit: Int) -> [Suggestion] {
    guard limit > 0 else {
        return []
    }

    let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)

    let matcher = FuzzyMatcher()
    let query = matcher.prepare(trimmedSearchTerm)
    var buffer = matcher.makeBuffer()

    return Array(
        filterHistoryEntries
            .lazy
            .compactMap { entry in
                let filterText = entry.filter.description

                if trimmedSearchTerm.isEmpty {
                    return Suggestion(
                        source: .historyFilter,
                        content: .filter(WithHighlightedString(value: entry.filter, string: filterText, searchTerm: searchTerm)),
                        score: 0,
                    )
                }

                if let match = matcher.score(filterText, against: query, buffer: &buffer) {
                    return Suggestion(
                        source: .historyFilter,
                        content: .filter(WithHighlightedString(value: entry.filter, string: filterText, searchTerm: searchTerm)),
                        score: match.score,
                    )
                }

                return nil
            }
            .prefix(limit)
    )
}

func filterTypeSuggestions(for partial: PartialFilterTerm, searchTerm: String, limit: Int) -> [Suggestion] {
    guard limit > 0,
        case .name(let exact, let partialTerm) = partial.content,
        !exact,
        partialTerm.quotingType == nil else {
        return []
    }

    let filterName = partialTerm.incompleteContent

    if filterName.isEmpty {
        return []
    }

    var seen = Set<String>()
    var deduplicated: [(String, ScryfallFilterType, Double)] = []
    for result in FuzzyMatcher().matches(Array(scryfallFilterByType.keys), against: filterName) {
        if let filterType = scryfallFilterByType[result.candidate], seen.insert(filterType.canonicalName).inserted {
            deduplicated.append((result.candidate, filterType, result.match.score))
        }
    }

    return Array(deduplicated.prefix(limit).map { candidate, filterType, score in
        let displayName = partial.polarity == .negative ? "-\(candidate)" : candidate
        return Suggestion(
            source: .filterType,
            content: .filterType(WithHighlightedString(value: FilterTypeSuggestion(polarity: partial.polarity, filterType: filterType), string: displayName, searchTerm: searchTerm)),
            score: score,
        )
    })
}

func enumerationSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String, limit: Int) -> [Suggestion] {
    guard limit > 0,
          case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
          let comparison = partialComparison.toComplete(),
          let filterType = scryfallFilterByType[filterTypeName.lowercased()],
          let allCandidates = catalogData[filterType] ?? filterType.enumerationValues else {
        return []
    }

    let value = partialValue.incompleteContent

    let matched: [(String, Double)]
    if value.isEmpty {
        matched = allCandidates.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map { ($0, 0) }
    } else {
        matched = timed("enumerationSuggestions fuzzy match") {
            FuzzyMatcher().matches(allCandidates, against: value).map { ($0.candidate, $0.match.score) }
        }
    }

    let allResults = matched.map { candidate, score in
        let filter = FilterTerm.basic(partial.polarity, filterTypeName.lowercased(), comparison, candidate)
        return Suggestion(
            source: .enumeration,
            content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
            score: score,
        )
    }

    return Array(allResults.prefix(limit))
}

func reverseEnumerationSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String, limit: Int) -> [Suggestion] {
    guard limit > 0,
          case .name(let isExact, let partialTerm) = partial.content,
          !isExact else {
        return []
    }

    let partialSearchTerm = partialTerm.incompleteContent

    guard partialSearchTerm.count >= 2 else {
        return []
    }

    let allCandidates = reverseEnumerationAllCandidates(catalogData: catalogData)

    guard !allCandidates.isEmpty else {
        return []
    }

    let matchResults = timed("reverseEnumerationSuggestions fuzzy match") {
        FuzzyMatcher().matches(allCandidates.map(\.0), against: partialSearchTerm)
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

private func reverseEnumerationAllCandidates(catalogData: EnumerationCatalogData) -> [(String, [ScryfallFilterType])] {
    var valueToFilters = reverseEnumerationStaticIndex()

    for (key, value) in reverseEnumerationDynamicIndex(catalogData: catalogData) {
        valueToFilters[key, default: []].append(contentsOf: value)
    }

    return valueToFilters.map { ($0.key, $0.value) }
}

private func reverseEnumerationStaticIndex() -> [String: [ScryfallFilterType]] {
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

private func reverseEnumerationDynamicIndex(catalogData: EnumerationCatalogData) -> [String: [ScryfallFilterType]] {
    var valueToFilters = [String: [ScryfallFilterType]]()

    for filterType in scryfallFilterTypes {
        guard let values = catalogData[filterType] else { continue }
        for value in values {
            valueToFilters[value, default: []].append(filterType)
        }
    }

    return valueToFilters
}

func nameSuggestions(for partial: PartialFilterTerm, in cardNames: [String], searchTerm: String, limit: Int) -> [Suggestion] {
    guard limit > 0 else {
        return []
    }

    let name: String
    let comparison: Comparison?

    switch partial.content {
    case .name(_, let partialValue):
        name = partialValue.incompleteContent
        comparison = nil
    case .filter(let filter, let partialComparison, let partialValue):
        if let completeComparison = partialComparison.toComplete(), filter.lowercased() == "name" && (
            completeComparison == .including || completeComparison == .equal || completeComparison == .notEqual
        ) {
            name = partialValue.incompleteContent
            comparison = completeComparison
        } else {
            name = ""
            comparison = nil
        }
    }

    guard name.count >= 2 else {
        return []
    }

    let matches = timed("nameSuggestions fuzzy match") {
        FuzzyMatcher().matches(cardNames, against: name)
    }

    return Array(matches
        .lazy
        .prefix(limit)
        .map { result in
            let cardName = result.candidate
            let filter: FilterTerm
            if let comparison {
                filter = .basic(partial.polarity, "name", comparison, cardName)
            } else {
                filter = .name(partial.polarity, true, cardName)
            }

            return Suggestion(
                source: .name,
                content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
                score: result.match.score,
            )
        }
     )
}
