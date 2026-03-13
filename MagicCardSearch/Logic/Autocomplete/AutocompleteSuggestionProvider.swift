import Foundation
import FuzzyMatch
import SQLiteData
import ScryfallKit

struct AutocompleteSuggestion {
    enum Source: Equatable {
        case pinnedFilter, historyFilter, filterType, enumeration, reverseEnumeration, name, fullText
    }

    struct Match<T: Sendable>: Sendable {
        let value: T
        let string: String
        let highlights: [Range<String.Index>]
    }

    enum Content {
        case filter(Match<FilterQuery<FilterTerm>>)
        case filterType(Match<FilterTypeSuggestion>)
        case filterParts(Polarity, ScryfallFilterType, Match<String>)
    }

    let source: Source
    let content: Content
    let rawScore: Double
    let biasedScore: Double
}

struct FilterTypeSuggestion: Hashable, Sendable {
    let polarity: Polarity
    let filterType: ScryfallFilterType
}

// Gaussian decay scoring, following Elasticsearch's function score model:
// https://www.elastic.co/blog/found-function-scoring
//
// - offset: flat zone near origin where score stays at maxBias
// - scale: age at which the gaussian factor reaches `decay`, i.e. the steepest region
// - decay: gaussian factor value at age == offset + scale
func recencyBias(for: Date) -> Double {
    let maxBias: Double = 1.5
    let minBias: Double = 1.0
    let offset: TimeInterval = 0
    let scale: TimeInterval = 6 * 24 * 3600
    let decay: Double = 0.5

    let adjusted = max(0, -`for`.timeIntervalSinceNow - offset)
    let gaussianFactor = exp(log(decay) * pow(adjusted / scale, 2))
    return minBias + (maxBias - minBias) * gaussianFactor
}

@MainActor
class AutocompleteSuggestionProvider {
    private let scryfallCatalogs: ScryfallCatalogs

    @ObservationIgnored @FetchAll
    private var pinnedFilters: [PinnedFilterEntry]

    @ObservationIgnored @FetchAll(FilterHistoryEntry.order { $0.lastUsedAt.desc() })
    private var filterHistoryEntries

    init(scryfallCatalogs: ScryfallCatalogs) {
        self.scryfallCatalogs = scryfallCatalogs
    }

    // swiftlint:disable:next function_body_length
    func getSuggestions(for searchTerm: String, existingFilters: Set<FilterQuery<FilterTerm>>)
        async throws -> [AutocompleteSuggestion]
    {
        let filters = pinnedFilters
        let history = filterHistoryEntries
        let catalogData = EnumerationCatalogData(scryfallCatalogs: scryfallCatalogs)
        let cardNames = scryfallCatalogs.cardNames

        return try await Task.detached(priority: .userInitiated) {
            try timed("aggregated autocomplete suggestions", warnThreshold: .milliseconds(50)) {
                let partial = PartialFilterTerm.from(searchTerm)

                var suggestions: [AutocompleteSuggestion] = []

                try Task.checkCancellation()
                suggestions.append(
                    contentsOf: timed("pinned filter autocomplete suggestions") {
                        pinnedFilterSuggestions(
                            for: partial,
                            from: filters,
                            searchTerm: searchTerm
                        )
                        .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                    }
                )

                try Task.checkCancellation()
                suggestions.append(
                    contentsOf: timed("filter history autocomplete suggestions") {
                        filterHistorySuggestions(for: searchTerm, from: history)
                            .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                            .prefix(20)
                    }
                )

                try Task.checkCancellation()
                suggestions.append(
                    contentsOf: timed("filter type autocomplete suggestions") {
                        filterTypeSuggestions(for: partial, searchTerm: searchTerm)
                            .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                            .prefix(4)
                    }
                )

                try Task.checkCancellation()
                suggestions.append(
                    contentsOf: timed("full text autocomplete suggestions") {
                        fullTextSuggestion(for: partial, searchTerm: searchTerm)
                            .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                    }
                )

                try Task.checkCancellation()
                suggestions.append(
                    contentsOf: timed("reverse enumeration autocomplete suggestions") {
                        reverseEnumerationSuggestions(
                            for: partial,
                            catalogData: catalogData,
                            searchTerm: searchTerm
                        )
                        .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                        .prefix(20)
                    }
                )

                try Task.checkCancellation()
                suggestions.append(
                    contentsOf: timed("enumeration autocomplete suggestions") {
                        enumerationSuggestions(
                            for: partial,
                            catalogData: catalogData,
                            searchTerm: searchTerm
                        )
                        .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                        .prefix(20)
                    }
                )

                if let cardNames {
                    try Task.checkCancellation()
                    suggestions.append( contentsOf:
                        timed("name autocomplete suggestions") {
                            nameSuggestions(for: partial, in: cardNames, searchTerm: searchTerm)
                                .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                                .prefix(10)
                        }
                    )
                }

                try Task.checkCancellation()
                return sortCombinedSuggestions(suggestions)
            }
        }.value
    }
}

private let fuzzyMatcher = FuzzyMatcher(
    config: MatchConfig(
        minScore: 0.85,
        algorithm: .editDistance(
            .init(
                maxEditDistance: 2,
                longQueryMaxEditDistance: 3,
                longQueryThreshold: 10,
                prefixWeight: 2.0,
                substringWeight: 1.2,
                wordBoundaryBonus: 0.125,
                consecutiveBonus: 0.07,
                gapPenalty: .affine(open: 0.05, extend: 0.01),
                firstMatchBonus: 0.25,
                firstMatchBonusRange: 3,
                lengthPenalty: 0.005,
                acronymWeight: 0.5,
            )
        )
    )
)

private func isRedundantSuggestion(
    _ suggestion: AutocompleteSuggestion,
    existingFilters: Set<FilterQuery<FilterTerm>>,
) -> Bool {
    if case .filter(let match) = suggestion.content, existingFilters.contains(match.value) {
        true
    } else {
        false
    }
}

// Visible for testing.
func sortCombinedSuggestions(_ suggestions: [AutocompleteSuggestion]) -> [AutocompleteSuggestion] {
    var seen = Set<FilterQuery<FilterTerm>>()
    return
        suggestions
        .filter {
            guard case .filter(let match) = $0.content else { return true }
            return seen.insert(match.value).inserted
        }
        .sorted { $0.biasedScore > $1.biasedScore }
}

func pinnedFilterSuggestions(
    for partial: PartialFilterTerm,
    from pinnedFilters: [PinnedFilterEntry],
    searchTerm: String
) -> some Sequence<AutocompleteSuggestion> {
    let trimmedSearchTerm = partial.description.trimmingCharacters(in: .whitespaces)
    let filterByText = Dictionary(
        pinnedFilters.map { ($0.filter.description, $0.filter) },
        // swiftlint:disable:next trailing_closure
        uniquingKeysWith: { first, _ in first },
    )

    let query = fuzzyMatcher.prepare(trimmedSearchTerm)
    return fuzzyMatcher.matches(Array(filterByText.keys), against: query)
        .lazy
        .map { result in
            AutocompleteSuggestion(
                source: .pinnedFilter,
                content: .filter(
                    .init(
                        value: filterByText[result.candidate]!,
                        string: result.candidate,
                        highlights: fuzzyMatcher.highlight(result.candidate, against: query) ?? [],
                    ),
                ),
                rawScore: result.match.score,
                biasedScore: result.match.score + 10,
            )
        }
}

func filterHistorySuggestions(
    for searchTerm: String,
    from filterHistoryEntries: [FilterHistoryEntry]
) -> some Sequence<AutocompleteSuggestion> {
    let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)

    guard !trimmedSearchTerm.isEmpty else {
        return AnySequence(
            filterHistoryEntries
                .lazy
                .map {
                    AutocompleteSuggestion(
                        source: .historyFilter,
                        content: .filter(
                            .init(
                                value: $0.filter,
                                string: $0.filter.description,
                                highlights: [],
                            ),
                        ),
                        rawScore: 1.0,
                        biasedScore: 1.0 * recencyBias(for: $0.lastUsedAt) - 0.6,
                    )
                }
        )
    }

    let entryByFilterDescription = Dictionary(
        filterHistoryEntries.map { ($0.filter.description, $0) },
        // swiftlint:disable:next trailing_closure
        uniquingKeysWith: { first, _ in first },
    )

    let query = fuzzyMatcher.prepare(trimmedSearchTerm)
    return AnySequence(
        fuzzyMatcher.matches(Array(entryByFilterDescription.keys), against: query)
            .lazy
            .map { result in
                let entry = entryByFilterDescription[result.candidate]!
                return AutocompleteSuggestion(
                    source: .historyFilter,
                    content: .filter(
                        .init(
                            value: entry.filter,
                            string: result.candidate,
                            highlights: fuzzyMatcher.highlight(result.candidate, against: query)
                                ?? [],
                        ),
                    ),
                    rawScore: result.match.score,
                    biasedScore: result.match.score * recencyBias(for: entry.lastUsedAt) - 0.6,
                )
            }
    )
}

extension [Range<String.Index>] {
    fileprivate func shift(by count: Int, in string: String) -> [Range<String.Index>] {
        guard count != 0 else { return self }
        return compactMap { range in
            guard
                let lower = string.index(
                    range.lowerBound,
                    offsetBy: count,
                    limitedBy: string.endIndex
                ),
                let upper = string.index(
                    range.upperBound,
                    offsetBy: count,
                    limitedBy: string.endIndex
                )
            else { return nil }
            return lower..<upper
        }
    }
}

func filterTypeSuggestions(for partial: PartialFilterTerm, searchTerm: String) -> some Sequence<
    AutocompleteSuggestion
> {
    guard case .name(let exact, let partialTerm) = partial.content,
        !exact,
        partialTerm.quotingType == nil,
        !partialTerm.incompleteContent.isEmpty
    else {
        return AnySequence([])
    }

    let query = fuzzyMatcher.prepare(partialTerm.incompleteContent)
    var seen = Set<String>()
    var deduplicated: [(String, ScryfallFilterType, Double)] = []
    for result in fuzzyMatcher.matches(Array(scryfallFilterByType.keys), against: query) {
        if let filterType = scryfallFilterByType[result.candidate],
            seen.insert(filterType.canonicalName).inserted
        {
            deduplicated.append((result.candidate, filterType, result.match.score))
        }
    }

    return AnySequence(
        deduplicated
            .lazy
            .map { candidate, filterType, score in
                let string = partial.polarity == .negative ? "-\(candidate)" : candidate
                return AutocompleteSuggestion(
                    source: .filterType,
                    content: .filterType(
                        .init(
                            value: FilterTypeSuggestion(
                                polarity: partial.polarity,
                                filterType: filterType
                            ),
                            string: string,
                            highlights: (fuzzyMatcher.highlight(candidate, against: query) ?? [])
                                .shift(by: partial.polarity == .negative ? 1 : 0, in: string),
                        ),
                    ),
                    rawScore: score,
                    biasedScore: score,
                )
            }
    )
}

func fullTextSuggestion(for partial: PartialFilterTerm, searchTerm: String) -> some Sequence<
    AutocompleteSuggestion
> {
    guard case .name(let isExact, let partialValue) = partial.content,
        !isExact
    else {
        return AnySequence([])
    }

    let bareTerm = partialValue.incompleteContent

    guard bareTerm.count > 3 && bareTerm.contains(" ") else {
        return AnySequence([])
    }

    let oracleFilter = FilterTerm.basic(partial.polarity, "oracle", .including, bareTerm)
    let flavorFilter = FilterTerm.basic(partial.polarity, "flavor", .including, bareTerm)

    return AnySequence([
        AutocompleteSuggestion(
            source: .fullText,
            content: .filter(
                .init(
                    value: .term(oracleFilter),
                    string: oracleFilter.description,
                    highlights: [oracleFilter.suggestedEditingRange],  // this is a wee hack
                ),
            ),
            rawScore: 0.95,  // ???
            biasedScore: 0.95,
        ),
        AutocompleteSuggestion(
            source: .fullText,
            content: .filter(
                .init(
                    value: .term(flavorFilter),
                    string: flavorFilter.description,
                    highlights: [flavorFilter.suggestedEditingRange],  // this is a wee hack
                ),
            ),
            rawScore: 0.9,  // ???
            biasedScore: 0.9,
        ),
    ])
}

func enumerationSuggestions(
    for partial: PartialFilterTerm,
    catalogData: EnumerationCatalogData,
    searchTerm: String
) -> some Sequence<AutocompleteSuggestion> {
    guard
        case .filter(let filterTypeName, let partialComparison, let partialValue) = partial.content,
        let comparison = partialComparison.toComplete(),
        let filterType = scryfallFilterByType[filterTypeName.lowercased()],
        let allCandidates = catalogData[filterType] ?? filterType.enumerationValues
    else {
        return AnySequence([])
    }

    let query = fuzzyMatcher.prepare(partialValue.incompleteContent)

    let matched: [(String, Double)] =
        if query.original.isEmpty {
            allCandidates.sorted { $0.localizedStandardCompare($1) == .orderedAscending }.map {
                ($0, 0)
            }
        } else {
            timed("enumerationSuggestions fuzzy match") {
                fuzzyMatcher.matches(allCandidates, against: query).map {
                    ($0.candidate, $0.match.score)
                }
            }
        }

    return AnySequence(
        matched
            .lazy
            .map { candidate, score in
                let filter = FilterTerm.basic(
                    partial.polarity,
                    filterTypeName.lowercased(),
                    comparison,
                    candidate
                )
                let filterText = filter.description
                return AutocompleteSuggestion(
                    source: .enumeration,
                    content: .filter(
                        .init(
                            value: .term(filter),
                            string: filterText,
                            highlights: (query.original.isEmpty
                                ? [] : fuzzyMatcher.highlight(candidate, against: query) ?? [])
                                .shift(
                                    by: filterText.distance(
                                        from: filterText.startIndex,
                                        to: filter.suggestedEditingRange.lowerBound
                                    ),
                                    in: filterText,
                                ),
                        ),
                    ),
                    rawScore: score,
                    biasedScore: score,
                )
            }
    )
}

func reverseEnumerationSuggestions(
    for partial: PartialFilterTerm,
    catalogData: EnumerationCatalogData,
    searchTerm: String
) -> some Sequence<AutocompleteSuggestion> {
    guard case .name(let isExact, let partialTerm) = partial.content,
        !isExact,
        partialTerm.incompleteContent.count >= 2
    else {
        return AnySequence([])
    }

    // These enumerations are very prolific and cluttery; their match scores are penalized accordingly.
    let biasedFilterTypes: [String: Double] = [
        "art": -0.4,  // extremely cluttery
        "artist": -0.2,  // marginally less cluttery but not terribly useful
        "block": -0.1,
        "frame": -0.1,
        "function": -0.2,  // cluttery but often very useful
        "set": -0.1,
        "watermark": -0.4,  // not super cluttery but also almost never useful
    ]

    let query = fuzzyMatcher.prepare(partialTerm.incompleteContent)
    let matchResults:
        [(candidate: String, filterTypes: [ScryfallFilterType], score: Double, biasedScore: Double)] =
            timed("reverseEnumerationSuggestions fuzzy match") {
                var buffer = fuzzyMatcher.makeBuffer()

                var results:
                    [(
                        candidate: String, filterTypes: [ScryfallFilterType], score: Double,
                        biasedScore: Double
                    )] = []
                var unbiasedValueToFilterTypes: [String: [ScryfallFilterType]] = [:]
                for filterType in scryfallFilterTypes {
                    let values = catalogData[filterType] ?? filterType.enumerationValues ?? []
                    guard !values.isEmpty else { continue }
                    if let bias = biasedFilterTypes[filterType.canonicalName] {
                        for candidate in values {
                            if let match = fuzzyMatcher.score(
                                candidate,
                                against: query,
                                buffer: &buffer
                            ) {
                                results.append(
                                    (candidate, [filterType], match.score, match.score + bias)
                                )
                            }
                        }
                    } else {
                        for value in values {
                            unbiasedValueToFilterTypes[value, default: []].append(filterType)
                        }
                    }
                }
                for candidate in unbiasedValueToFilterTypes.keys {
                    if let match = fuzzyMatcher.score(candidate, against: query, buffer: &buffer) {
                        results.append(
                            (
                                candidate, unbiasedValueToFilterTypes[candidate]!, match.score,
                                match.score
                            )
                        )
                    }
                }
                return results.sorted { $0.biasedScore > $1.biasedScore }
            }

    return AnySequence(
        matchResults
            .lazy
            .flatMap { candidate, filterTypes, score, biasedScore -> [AutocompleteSuggestion] in
                filterTypes.map { filterType in
                    AutocompleteSuggestion(
                        source: .reverseEnumeration,
                        content: .filterParts(
                            partial.polarity,
                            filterType,
                            .init(
                                value: candidate,
                                string: candidate,
                                highlights: fuzzyMatcher.highlight(candidate, against: query) ?? [],
                            ),
                        ),
                        rawScore: score,
                        biasedScore: biasedScore,
                    )
                }
            }
    )
}

func nameSuggestions(for partial: PartialFilterTerm, in cardNames: [String], searchTerm: String)
    -> some Sequence<AutocompleteSuggestion>
{
    let name: String
    let comparison: Comparison?

    switch partial.content {
    case .name(_, let partialValue):
        name = partialValue.incompleteContent
        comparison = nil
    case .filter(let filter, let partialComparison, let partialValue):
        if let completeComparison = partialComparison.toComplete(),
            filter.lowercased() == "name"
                && (completeComparison == .including || completeComparison == .equal
                    || completeComparison == .notEqual)
        {
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

    let query = fuzzyMatcher.prepare(name)
    let matches = timed("nameSuggestions fuzzy match") {
        fuzzyMatcher.matches(cardNames, against: query)
    }

    return AnySequence(
        matches
            .lazy
            .map { result in
                let filter: FilterTerm =
                    if let comparison {
                        .basic(partial.polarity, "name", comparison, result.candidate)
                    } else {
                        .name(partial.polarity, true, result.candidate)
                    }
                let filterText = filter.description

                return AutocompleteSuggestion(
                    source: .name,
                    content: .filter(
                        .init(
                            value: .term(filter),
                            string: filterText,
                            highlights: (fuzzyMatcher.highlight(result.candidate, against: query)
                                ?? [])
                                .shift(
                                    by: filterText.distance(
                                        from: filterText.startIndex,
                                        to: filter.suggestedEditingRange.lowerBound
                                    ),
                                    in: filterText,
                                )
                        ),
                    ),
                    rawScore: result.match.score,
                    biasedScore: result.match.score,
                )
            }
    )
}
