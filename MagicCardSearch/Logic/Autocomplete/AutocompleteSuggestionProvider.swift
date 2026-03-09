import Foundation
import SQLiteData
import FuzzyMatch
import ScryfallKit
import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "AutocompleteSuggestionProvider")

struct AutocompleteSuggestion {
    enum Source: Equatable {
        case pinnedFilter, filterType, enumeration, reverseEnumeration, name, fullText
        case historyFilter(Date)
    }

    enum Content: Hashable {
        case filter(WithHighlightedString<FilterQuery<FilterTerm>>)
        case filterType(WithHighlightedString<FilterTypeSuggestion>)
        case filterParts(Polarity, ScryfallFilterType, WithHighlightedString<String>)
    }

    let source: Source
    let content: Content
    let score: Double

    // These enumerations are very prolific and cluttery.
    static let penalizedFilterTypes: [String: Double] = [
        "art": -0.4, // extremely cluttery
        "artist": -0.2, // marginally less cluttery but not terribly useful
        "block": -0.1,
        "frame": -0.1,
        "function": -0.2, // cluttery but often very useful
        "set": -0.1,
        "watermark": -0.4, // not super cluttery but also almost never useful
    ]

    var biasedScore: Double {
        return score * proportionalBias + fixedBias
    }

    private var fixedBias: Double {
        switch source {
        case .pinnedFilter: 10 // ALWAYS at the top
        case .historyFilter: -0.6 // give them a shot to be more interesting than the penalized reverse-enumerations
        case .reverseEnumeration:
            if case .filterParts(_, let filterType, _) = content {
                Self.penalizedFilterTypes[filterType.canonicalName] ?? 0
            } else {
                0
            }
        case .filterType, .enumeration, .name, .fullText: 0
        }
    }

    private var proportionalBias: Double {
        switch source {
        case .historyFilter(let lastUsedAt):
            Self.recencyBias(age: -lastUsedAt.timeIntervalSinceNow)
        case .pinnedFilter, .filterType, .enumeration, .reverseEnumeration, .name, .fullText: 1
        }
    }

    // Gaussian decay scoring, following Elasticsearch's function score model:
    // https://www.elastic.co/blog/found-function-scoring
    //
    // - offset: flat zone near origin where score stays at maxBias
    // - scale: age at which the gaussian factor reaches `decay`, i.e. the steepest region
    // - decay: gaussian factor value at age == offset + scale
    static func recencyBias(
        age: TimeInterval,
        maxBias: Double = 1.5,
        minBias: Double = 1.0,
        offset: TimeInterval = 2 * 24 * 3600,
        scale: TimeInterval = 5 * 24 * 3600,
        decay: Double = 0.5
    ) -> Double {
        let adjusted = max(0, age - offset)
        let gaussianFactor = exp(log(decay) * pow(adjusted / scale, 2))
        return minBias + (maxBias - minBias) * gaussianFactor
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

    // swiftlint:disable:next function_body_length
    func getSuggestions(for searchTerm: String, existingFilters: Set<FilterQuery<FilterTerm>>) -> AsyncStream<[AutocompleteSuggestion]> {
        let partial = PartialFilterTerm.from(searchTerm)

        let (stream, continuation) = AsyncStream.makeStream(of: [AutocompleteSuggestion].self)

        let task = Task {
            await withTaskGroup(of: [AutocompleteSuggestion].self) { group in
                let catalogData = EnumerationCatalogData(scryfallCatalogs: self.scryfallCatalogs)

                do {
                    let filters = pinnedFilters
                    group.addTask {
                        timed("pinned filter autocomplete suggestions") {
                            Array(
                                pinnedFilterSuggestions(for: partial, from: filters, searchTerm: searchTerm)
                                    .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                            )
                        }
                    }
                }
                do {
                    let history = filterHistoryEntries
                    group.addTask {
                        timed("filter history autocomplete suggestions") {
                            Array(
                                filterHistorySuggestions(for: searchTerm, from: history)
                                    .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                                    .prefix(20)
                            )
                        }
                    }
                }
                group.addTask {
                    timed("filter type autocomplete suggestions") {
                        Array(
                            filterTypeSuggestions(for: partial, searchTerm: searchTerm)
                                .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                                .prefix(4)
                        )
                    }
                }
                group.addTask {
                    timed("full text autocomplete suggestions") {
                        Array(
                            fullTextSuggestion(for: partial, searchTerm: searchTerm)
                                .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                        )
                    }
                }
                group.addTask {
                    timed("reverse enumeration autocomplete suggestions") {
                        Array(
                            reverseEnumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: searchTerm)
                                .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                                .prefix(20)
                        )
                    }
                }
                group.addTask {
                    timed("enumeration autocomplete suggestions") {
                        Array(
                            enumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: searchTerm)
                                .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                                .prefix(20)
                        )
                    }
                }
                if let cardNames = self.scryfallCatalogs.cardNames {
                    group.addTask {
                        timed("name autocomplete suggestions") {
                            Array(
                                nameSuggestions(for: partial, in: cardNames, searchTerm: searchTerm)
                                    .filter { !isRedundantSuggestion($0, existingFilters: existingFilters) }
                                    .prefix(10)
                            )
                        }
                    }
                }

                var suggestions: [AutocompleteSuggestion] = []
                for await batch in group {
                    suggestions.append(contentsOf: batch)
                    continuation.yield(sortCombinedSuggestions(suggestions))
                }
                continuation.finish()
            }
        }

        continuation.onTermination = { _ in
            logger.debug("autocomplete suggestion consumer terminated; cancelling")
            task.cancel()
        }

        return stream
    }
}

let fuzzyMatchConfig = MatchConfig(
    minScore: 0.85,
    algorithm: .editDistance(
        .init(
            maxEditDistance: 2,
            prefixWeight: 2.0,
            substringWeight: 1.2,
            wordBoundaryBonus: 0.125,
            consecutiveBonus: 0.06,
            gapPenalty: .affine(open: 0.05, extend: 0.01),
            firstMatchBonus: 0.25,
            firstMatchBonusRange: 3,
            acronymWeight: 0.5,
        )
    )
)

private func isRedundantSuggestion(
    _ suggestion: AutocompleteSuggestion,
    existingFilters: Set<FilterQuery<FilterTerm>>,
) -> Bool {
    if case .filter(let highlighted) = suggestion.content, existingFilters.contains(highlighted.value) {
        true
    } else {
        false
    }
}

func sortCombinedSuggestions(_ suggestions: [AutocompleteSuggestion]) -> [AutocompleteSuggestion] {
    var seen = Set<AutocompleteSuggestion.Content>()
    return suggestions
        .sorted { $0.biasedScore > $1.biasedScore }
        .filter { seen.insert($0.content).inserted }
}

func pinnedFilterSuggestions(for partial: PartialFilterTerm, from pinnedFilters: [PinnedFilterEntry], searchTerm: String) -> some Sequence<AutocompleteSuggestion> {
    let trimmedSearchTerm = partial.description.trimmingCharacters(in: .whitespaces)
    let filterByText = Dictionary(
        pinnedFilters.map { ($0.filter.description, $0.filter) },
        // swiftlint:disable:next trailing_closure
        uniquingKeysWith: { first, _ in first },
    )

    return FuzzyMatcher(config: fuzzyMatchConfig).matches(Array(filterByText.keys), against: trimmedSearchTerm)
        .lazy
        .map { result in
            AutocompleteSuggestion(
                source: .pinnedFilter,
                content: .filter(WithHighlightedString(value: filterByText[result.candidate]!, string: result.candidate, searchTerm: searchTerm)),
                score: result.match.score,
            )
        }
}

func filterHistorySuggestions(for searchTerm: String, from filterHistoryEntries: [FilterHistoryEntry]) -> some Sequence<AutocompleteSuggestion> {
    let trimmedSearchTerm = searchTerm.trimmingCharacters(in: .whitespaces)
    let entryByFilterDescription = Dictionary(
        filterHistoryEntries.map { ($0.filter.description, $0) },
        // swiftlint:disable:next trailing_closure
        uniquingKeysWith: { first, _ in first },
    )

    return FuzzyMatcher(config: fuzzyMatchConfig).matches(Array(entryByFilterDescription.keys), against: trimmedSearchTerm)
        .lazy
        .map { result in
            let entry = entryByFilterDescription[result.candidate]!
            return AutocompleteSuggestion(
                source: .historyFilter(entry.lastUsedAt),
                content: .filter(WithHighlightedString(value: entry.filter, string: result.candidate, searchTerm: searchTerm)),
                score: result.match.score,
            )
        }
}

func filterTypeSuggestions(for partial: PartialFilterTerm, searchTerm: String) -> some Sequence<AutocompleteSuggestion> {
    guard case .name(let exact, let partialTerm) = partial.content,
        !exact,
        partialTerm.quotingType == nil,
        !partialTerm.incompleteContent.isEmpty else {
        return AnySequence([])
    }

    let filterName = partialTerm.incompleteContent
    var seen = Set<String>()
    var deduplicated: [(String, ScryfallFilterType, Double)] = []
    for result in FuzzyMatcher(config: fuzzyMatchConfig).matches(Array(scryfallFilterByType.keys), against: filterName) {
        if let filterType = scryfallFilterByType[result.candidate], seen.insert(filterType.canonicalName).inserted {
            deduplicated.append((result.candidate, filterType, result.match.score))
        }
    }

    return AnySequence(deduplicated
        .lazy
        .map { candidate, filterType, score in
            let displayName = partial.polarity == .negative ? "-\(candidate)" : candidate
            return AutocompleteSuggestion(
                source: .filterType,
                content: .filterType(WithHighlightedString(value: FilterTypeSuggestion(polarity: partial.polarity, filterType: filterType), string: displayName, searchTerm: searchTerm)),
                score: score,
            )
        }
    )
}

func fullTextSuggestion(for partial: PartialFilterTerm, searchTerm: String) -> some Sequence<AutocompleteSuggestion> {
    guard case .name(let isExact, let partialValue) = partial.content,
        !isExact else {
        return AnySequence([])
      }

    let bareTerm = partialValue.incompleteContent

    guard bareTerm.count > 3 && bareTerm.contains(" ") else {
        return AnySequence([])
    }

    let oracleFilter = FilterTerm.basic(partial.polarity, "oracle", .including, bareTerm)
    let flavorFilter = FilterTerm.basic(partial.polarity, "flavor", .including, bareTerm)

    return AnySequence([
        .init(
            source: .fullText,
            content: .filter(
                WithHighlightedString(value: .term(oracleFilter), string: oracleFilter.description, searchTerm: searchTerm),
            ),
            score: 0.95, // ???
        ),
        .init(
            source: .fullText,
            content: .filter(
                WithHighlightedString(value: .term(flavorFilter), string: flavorFilter.description, searchTerm: searchTerm),
            ),
            score: 0.9, // ???
        ),
    ])
}

func enumerationSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String) -> some Sequence<AutocompleteSuggestion> {
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
            FuzzyMatcher(config: fuzzyMatchConfig).matches(allCandidates, against: value).map { ($0.candidate, $0.match.score) }
        }
    }

    return AnySequence(matched
        .lazy
        .map { candidate, score in
            let filter = FilterTerm.basic(partial.polarity, filterTypeName.lowercased(), comparison, candidate)
            return AutocompleteSuggestion(
                source: .enumeration,
                content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
                score: score,
            )
        }
    )
}

func reverseEnumerationSuggestions(for partial: PartialFilterTerm, catalogData: EnumerationCatalogData, searchTerm: String) -> some Sequence<AutocompleteSuggestion> {
    guard case .name(let isExact, let partialTerm) = partial.content,
          !isExact,
          partialTerm.incompleteContent.count >= 2 else {
        return AnySequence([])
    }

    let valueToFilters = timed("reverseEnumerationSuggestions mapping initialization") {
        var valueToFilters = [String: [ScryfallFilterType]]()
        for filterType in scryfallFilterTypes {
            for value in catalogData[filterType] ?? filterType.enumerationValues ?? [] {
                valueToFilters[value, default: []].append(filterType)
            }
        }
        return valueToFilters
    }

    guard !valueToFilters.isEmpty else {
        return AnySequence([])
    }

    let matchResults = timed("reverseEnumerationSuggestions fuzzy match") {
        FuzzyMatcher(config: fuzzyMatchConfig).matches(Array(valueToFilters.keys), against: partialTerm.incompleteContent)
    }

    return AnySequence(
        matchResults
            .lazy
            .flatMap { result in
                guard let filters = valueToFilters[result.candidate] else {
                    return [AutocompleteSuggestion]()
                }
                return filters.map { filterType in
                    AutocompleteSuggestion(
                        source: .reverseEnumeration,
                        content: .filterParts(partial.polarity, filterType, WithHighlightedString(value: result.candidate, string: result.candidate, searchTerm: searchTerm)),
                        score: result.match.score,
                    )
                }
            }
    )
}

func nameSuggestions(for partial: PartialFilterTerm, in cardNames: [String], searchTerm: String) -> some Sequence<AutocompleteSuggestion> {
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
        FuzzyMatcher(config: fuzzyMatchConfig).matches(cardNames, against: name)
    }

    return AnySequence(matches
        .lazy
        .map { result in
            let filter: FilterTerm = if let comparison {
                .basic(partial.polarity, "name", comparison, result.candidate)
            } else {
                .name(partial.polarity, true, result.candidate)
            }

            return AutocompleteSuggestion(
                source: .name,
                content: .filter(WithHighlightedString(value: .term(filter), string: filter.description, searchTerm: searchTerm)),
                score: result.match.score,
            )
        }
    )
}
