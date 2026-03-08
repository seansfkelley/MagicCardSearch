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
                        Array(
                            pinnedFilterSuggestions(for: partial, from: filters, searchTerm: searchTerm)
                                .filter { isRelevantSuggestion($0, searchTerm: searchTerm, existingFilters: existingFilters) }
                        )
                    }
                }
                do {
                    let history = filterHistoryEntries
                    group.addTask {
                        Array(
                            filterHistorySuggestions(for: searchTerm, from: history)
                                .filter { isRelevantSuggestion($0, searchTerm: searchTerm, existingFilters: existingFilters) }
                                .prefix(20)
                        )
                    }
                }
                group.addTask {
                    Array(
                        filterTypeSuggestions(for: partial, searchTerm: searchTerm)
                            .filter { isRelevantSuggestion($0, searchTerm: searchTerm, existingFilters: existingFilters) }
                            .prefix(4)
                    )
                }
                group.addTask {
                    Array(
                        reverseEnumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: searchTerm)
                            .filter { isRelevantSuggestion($0, searchTerm: searchTerm, existingFilters: existingFilters) }
                            .prefix(20)
                    )
                }
                group.addTask {
                    Array(
                        enumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: searchTerm)
                            .filter { isRelevantSuggestion($0, searchTerm: searchTerm, existingFilters: existingFilters) }
                            .prefix(40)
                    )
                }
                if let cardNames = self.scryfallCatalogs.cardNames {
                    group.addTask {
                        Array(
                            nameSuggestions(for: partial, in: cardNames, searchTerm: searchTerm)
                                .filter { isRelevantSuggestion($0, searchTerm: searchTerm, existingFilters: existingFilters) }
                                .prefix(10)
                        )
                    }
                }

                var suggestions: [Suggestion] = []
                for await batch in group {
                    suggestions.append(contentsOf: batch)
                    continuation.yield(sortCombinedSuggestions(suggestions))
                }
                continuation.finish()
            }
        }

        continuation.onTermination = { _ in task.cancel() }

        return stream
    }
}

private func isRelevantSuggestion(
    _ suggestion: Suggestion,
    searchTerm: String,
    existingFilters: Set<FilterQuery<FilterTerm>>,
) -> Bool {
    if case .filter(let highlighted) = suggestion.content {
        !existingFilters.contains(highlighted.value)
    } else if searchTerm.isEmpty {
        true
    } else {
        suggestion.score >= 0.8
    }
}

private func sortCombinedSuggestions(_ suggestions: [Suggestion]) -> [Suggestion] {
    var seen = Set<Suggestion.Content>()
    return suggestions
        .sorted { $0.biasedScore > $1.biasedScore }
        .filter { seen.insert($0.content).inserted }
}

func pinnedFilterSuggestions(for partial: PartialFilterTerm, from pinnedFilters: [PinnedFilterEntry], searchTerm: String) -> some Sequence<Suggestion> {
    let trimmedSearchTerm = partial.description.trimmingCharacters(in: .whitespaces)

    let matcher = FuzzyMatcher()
    let query = matcher.prepare(trimmedSearchTerm)
    var buffer = matcher.makeBuffer()

    return pinnedFilters
        .lazy
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

func filterHistorySuggestions(for searchTerm: String, from filterHistoryEntries: [FilterHistoryEntry]) -> some Sequence<Suggestion> {
    let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)

    let matcher = FuzzyMatcher()
    let query = matcher.prepare(trimmedSearchTerm)
    var buffer = matcher.makeBuffer()

    return filterHistoryEntries
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
}

func filterTypeSuggestions(for partial: PartialFilterTerm, searchTerm: String) -> some Sequence<Suggestion> {
    guard case .name(let exact, let partialTerm) = partial.content,
        !exact,
        partialTerm.quotingType == nil,
        !partialTerm.incompleteContent.isEmpty else {
        return AnySequence([])
    }

    let filterName = partialTerm.incompleteContent
    var seen = Set<String>()
    var deduplicated: [(String, ScryfallFilterType, Double)] = []
    for result in FuzzyMatcher().matches(Array(scryfallFilterByType.keys), against: filterName) {
        if let filterType = scryfallFilterByType[result.candidate], seen.insert(filterType.canonicalName).inserted {
            deduplicated.append((result.candidate, filterType, result.match.score))
        }
    }

    return AnySequence(deduplicated.lazy.map { candidate, filterType, score in
        let displayName = partial.polarity == .negative ? "-\(candidate)" : candidate
        return Suggestion(
            source: .filterType,
            content: .filterType(WithHighlightedString(value: FilterTypeSuggestion(polarity: partial.polarity, filterType: filterType), string: displayName, searchTerm: searchTerm)),
            score: score,
        )
    })
}

func enumerationSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String) -> some Sequence<Suggestion> {
    guard case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
          let comparison = partialComparison.toComplete(),
          let filterType = scryfallFilterByType[filterTypeName.lowercased()],
          let allCandidates = catalogData[filterType] ?? filterType.enumerationValues else {
        return AnySequence([])
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

    return AnySequence(matched.lazy.map { candidate, score in
        let filter = FilterTerm.basic(partial.polarity, filterTypeName.lowercased(), comparison, candidate)
        return Suggestion(
            source: .enumeration,
            content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
            score: score,
        )
    })
}

func reverseEnumerationSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String) -> some Sequence<Suggestion> {
    guard case .name(let isExact, let partialTerm) = partial.content,
          !isExact,
          partialTerm.incompleteContent.count >= 2 else {
        return AnySequence([])
    }

    let partialSearchTerm = partialTerm.incompleteContent
    let allCandidates = reverseEnumerationAllCandidates(catalogData: catalogData)

    guard !allCandidates.isEmpty else {
        return AnySequence([])
    }

    let matchResults = timed("reverseEnumerationSuggestions fuzzy match") {
        FuzzyMatcher().matches(allCandidates.map(\.0), against: partialSearchTerm)
    }

    return AnySequence(
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

func nameSuggestions(for partial: PartialFilterTerm, in cardNames: [String], searchTerm: String) -> some Sequence<Suggestion> {
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
        return AnySequence([])
    }

    let matches = timed("nameSuggestions fuzzy match") {
        FuzzyMatcher().matches(cardNames, against: name)
    }

    return AnySequence(matches.lazy.map { result in
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
    })
}
