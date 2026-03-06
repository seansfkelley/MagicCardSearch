import Foundation
import SQLiteData

struct Suggestion2 {
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
}

struct FilterTypeSuggestion: Hashable, Sendable {
    let polarity: Polarity
    let filterType: ScryfallFilterType
}

struct WithHighlightedString<T: Sendable & Hashable>: Hashable {
    let value: T
    let string: String
    lazy var highlights = guessHighlights()

    private let searchTerm: String

    init(value: T, string: String, searchTerm: String) {
        self.value = value
        self.string = string
        self.searchTerm = searchTerm
    }

    private func guessHighlights() -> [Range<String.Index>] {
        guard !searchTerm.isEmpty, !string.isEmpty else {
            return []
        }

        var ranges = [Range<String.Index>]()
        var stringIndex = string.startIndex

        for searchChar in searchTerm {
            // Find the next occurrence of this character in string.
            while stringIndex < string.endIndex {
                if string[stringIndex].lowercased() == searchChar.lowercased() {
                    let nextIndex = string.index(after: stringIndex)
                    // Extend the last range if this character is adjacent.
                    if let last = ranges.last, last.upperBound == stringIndex {
                        ranges[ranges.count - 1] = last.lowerBound..<nextIndex
                    } else {
                        ranges.append(stringIndex..<nextIndex)
                    }
                    stringIndex = nextIndex
                    break
                }
                stringIndex = string.index(after: stringIndex)
            }
        }

        return ranges
    }
}

@MainActor
class CombinedSuggestionProvider {
    private let pinnedFilterProvider = PinnedFilterSuggestionProvider()
    private let filterHistoryProvider = FilterHistorySuggestionProvider()
    private let filterTypeProvider = FilterTypeSuggestionProvider()
    private let enumerationProvider = EnumerationSuggestionProvider()
    private let reverseEnumerationProvider = ReverseEnumerationSuggestionProvider()
    private let nameProvider = NameSuggestionProvider()
    private let scryfallCatalogs: ScryfallCatalogs

    @ObservationIgnored @FetchAll private var pinnedFilters: [PinnedFilterEntry]
    @ObservationIgnored @FetchAll(FilterHistoryEntry.order { $0.lastUsedAt.desc() }) private var filterHistoryEntries

    init(scryfallCatalogs: ScryfallCatalogs) {
        self.scryfallCatalogs = scryfallCatalogs
    }

    func getSuggestions(for searchTerm: String, existingFilters: Set<FilterQuery<FilterTerm>>) -> AsyncStream<[Suggestion2]> {
        let partial = PartialFilterTerm.from(searchTerm)

        let (stream, continuation) = AsyncStream.makeStream(of: [Suggestion2].self)

        let task = Task {
            await withTaskGroup(of: [Suggestion2].self) { group in
                let catalogData = EnumerationCatalogData(scryfallCatalogs: self.scryfallCatalogs)

                do {
                    let filters = pinnedFilters
                    group.addTask {
                        self.pinnedFilterProvider.getSuggestions(for: partial, from: filters, searchTerm: searchTerm)
                    }
                }
                do {
                    let history = filterHistoryEntries
                    group.addTask {
                        self.filterHistoryProvider.getSuggestions(for: searchTerm, from: history, limit: 20)
                    }
                }
                group.addTask {
                    self.filterTypeProvider.getSuggestions(for: partial, searchTerm: searchTerm, limit: 4)
                }
                group.addTask {
                    await self.reverseEnumerationProvider.getSuggestions(for: partial, catalogData: catalogData, searchTerm: searchTerm, limit: 20)
                }
                group.addTask {
                    await self.enumerationProvider.getSuggestions(
                        for: partial,
                        catalogData: catalogData,
                        excluding: [],
                        searchTerm: searchTerm,
                        limit: 40,
                    )
                }
                if let cardNames = self.scryfallCatalogs.cardNames {
                    group.addTask {
                        await self.nameProvider.getSuggestions(for: partial, in: cardNames, searchTerm: searchTerm, limit: 10)
                    }
                }

                var suggestions: [Suggestion2] = []
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

private func sortCombinedSuggestions(_ suggestions: [Suggestion2]) -> [Suggestion2] {
    var seen = Set<Suggestion2.Content>()
    return suggestions
        .sorted { $0.biasedScore > $1.biasedScore }
        .filter { seen.insert($0.content).inserted }
}

private extension Suggestion2 {
    var biasedScore: Double {
        let bias: Double = switch source {
        case .pinnedFilter: 1
        case .historyFilter: -1
        case .filterType, .enumeration, .reverseEnumeration, .name: 0
        }
        return score + bias
    }
}
