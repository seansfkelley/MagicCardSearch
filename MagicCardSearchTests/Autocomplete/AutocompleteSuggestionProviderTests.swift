import Testing
import Foundation
import SQLiteData
import DependenciesTestSupport
@testable import MagicCardSearch

private func unwrap<T>(
    _ suggestions: some Sequence<AutocompleteSuggestion>,
    _ unwrapper: (AutocompleteSuggestion) -> T?,
) throws -> [T] {
    let arrayified = Array(suggestions)
    let unwrapped = arrayified.compactMap(unwrapper)
    try #require(unwrapped.count == arrayified.count)
    return unwrapped
}

private func unwrapFilter(_ suggestions: some Sequence<AutocompleteSuggestion>) throws -> [FilterQuery<FilterTerm>] {
    try unwrap(suggestions) {
        if case .filter(let result) = $0.content { result.value } else { nil }
    }
}

private func unwrapFilterType(_ suggestions: some Sequence<AutocompleteSuggestion>) throws -> [ScryfallFilterType] {
    try unwrap(suggestions) {
        if case .filterType(let result) = $0.content { result.value.filterType } else { nil }
    }
}

private typealias FilterParts = (polarity: Polarity, filterType: ScryfallFilterType, value: String)

private func unwrapFilterParts(_ suggestions: some Sequence<AutocompleteSuggestion>) throws -> [FilterParts] {
    try unwrap(suggestions) {
        if case .filterParts(let p, let ft, let h) = $0.content { (p, ft, h.value) } else { nil }
    }
}

// MARK: - filterHistorySuggestions

@Suite
struct FilterHistorySuggestionsTests {
    private let searchTerm = "fly"
    private let strongMatch = FilterQuery<FilterTerm>.term(.basic(.positive, "o", .including, "fly"))
    private let weakMatch = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))
    private let noMatch = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))

    private func entries(_ filters: [FilterQuery<FilterTerm>]) -> [FilterHistoryEntry] {
        filters.map { FilterHistoryEntry(filter: $0) }
    }

    @Test("empty history returns no suggestions")
    func empty() {
        #expect(Array(filterHistorySuggestions(for: searchTerm, from: [])).isEmpty)
    }

    @Test("non-matching search term returns no suggestions")
    func noMatches() {
        let suggestions = Array(filterHistorySuggestions(for: searchTerm, from: entries([noMatch])))
        #expect(suggestions.isEmpty)
    }

    @Test("matching entries are returned with historyFilter source")
    func matchingSource() throws {
        let suggestions = Array(filterHistorySuggestions(for: searchTerm, from: entries([strongMatch])))
        try #require(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { if case .historyFilter = $0.source { true } else { false } })
    }

    @Test("results are ordered by score, best match first")
    func ordering() throws {
        let suggestions = filterHistorySuggestions(for: searchTerm, from: entries([weakMatch, noMatch, strongMatch]))
        #expect(try unwrapFilter(suggestions) == [strongMatch, weakMatch])
    }

    @Test("empty search term returns all entries")
    func emptySearchTerm() throws {
        let suggestions = filterHistorySuggestions(for: "", from: entries([strongMatch, noMatch]))
        #expect(try unwrapFilter(suggestions) == [strongMatch, noMatch])
    }
}

// MARK: - pinnedFilterSuggestions

@Suite
struct PinnedFilterSuggestionsTests {
    private let searchTerm = "fly"
    private var partial: PartialFilterTerm {
        .init(polarity: .positive, content: .name(false, .bare(searchTerm)))
    }

    private let strongMatch = FilterQuery<FilterTerm>.term(.basic(.positive, "o", .including, "fly"))
    private let weakMatch = FilterQuery<FilterTerm>.term(.basic(.positive, "oracle", .including, "flying"))
    private let noMatch = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))

    private func entries(_ filters: [FilterQuery<FilterTerm>]) -> [PinnedFilterEntry] {
        filters.map { PinnedFilterEntry(filter: $0) }
    }

    @Test("empty pinned list returns no suggestions")
    func empty() {
        #expect(Array(pinnedFilterSuggestions(for: partial, from: [], searchTerm: searchTerm)).isEmpty)
    }

    @Test("non-matching entries return no suggestions")
    func noMatches() {
        let suggestions = Array(pinnedFilterSuggestions(for: partial, from: entries([noMatch]), searchTerm: searchTerm))
        #expect(suggestions.isEmpty)
    }

    @Test("matching entries are returned with pinnedFilter source")
    func matchingSource() throws {
        let suggestions = Array(pinnedFilterSuggestions(for: partial, from: entries([strongMatch]), searchTerm: searchTerm))
        try #require(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { $0.source == .pinnedFilter })
    }

    @Test("results are ordered by score, best match first")
    func ordering() throws {
        let suggestions = pinnedFilterSuggestions(for: partial, from: entries([weakMatch, noMatch, strongMatch]), searchTerm: searchTerm)
        #expect(try unwrapFilter(suggestions) == [strongMatch, weakMatch])
    }
}

// MARK: - filterTypeSuggestions

@Suite
struct FilterTypeSuggestionsTests {
    @Test("empty partial content returns no suggestions")
    func emptyContent() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("")))
        #expect(Array(filterTypeSuggestions(for: partial, searchTerm: "")).isEmpty)
    }

    @Test("exact-match content is ineligible")
    func exactMatch() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(true, .bare("format")))
        #expect(Array(filterTypeSuggestions(for: partial, searchTerm: "format")).isEmpty)
    }

    @Test("quoted content is ineligible")
    func quotedContent() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .unterminated(.doubleQuote, "forma")))
        #expect(Array(filterTypeSuggestions(for: partial, searchTerm: "forma")).isEmpty)
    }

    @Test("filter-with-operator content is ineligible")
    func filterWithOperator() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("forma", .including, .bare("")))
        #expect(Array(filterTypeSuggestions(for: partial, searchTerm: "forma")).isEmpty)
    }

    @Test("non-matching term returns no suggestions")
    func noMatches() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("zzzzz")))
        #expect(Array(filterTypeSuggestions(for: partial, searchTerm: "zzzzz")).isEmpty)
    }

    @Test("matching entries are returned with filterType source")
    func matchingSource() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("forma")))
        let suggestions = Array(filterTypeSuggestions(for: partial, searchTerm: "forma"))
        try #require(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { $0.source == .filterType })
    }

    @Test("results are ordered by score, best match first")
    func ordering() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("forma")))
        let suggestions = Array(filterTypeSuggestions(for: partial, searchTerm: "forma"))
        let names = (try unwrapFilterType(suggestions)).map(\.canonicalName)
        // "format" is a prefix match and should rank above "frame" (subsequence)
        #expect(names.first == "format")
        #expect(names.contains("frame"))
    }

    @Test("negative polarity prefixes display names with a dash")
    func negativePolarity() throws {
        let partial = PartialFilterTerm(polarity: .negative, content: .name(false, .bare("forma")))
        let suggestions = Array(filterTypeSuggestions(for: partial, searchTerm: "forma"))
        let first = try #require(suggestions.first).content
        if case .filterType(let result) = first {
            #expect(result.string == "-format")
        } else {
            Issue.record("incorrect suggestion type")
        }
    }

    @Test("deduplicates aliases that map to the same filter type")
    func deduplication() throws {
        // "o" is an alias for "oracle" and also matches a bunch of other filters and their aliases.
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("o")))
        let suggestions = Array(filterTypeSuggestions(for: partial, searchTerm: "o"))
        let filterTypes = try unwrapFilterType(suggestions)
        let uniqueFilterTypes = Set(filterTypes.map { $0.canonicalName })
        #expect(filterTypes.count == uniqueFilterTypes.count)
    }
}

// MARK: - fullTextSuggestion

@Suite
struct FullTextSuggestionTests {
    @Test("term without a space returns no suggestions")
    func noSpace() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("flying")))
        #expect(Array(fullTextSuggestion(for: partial, searchTerm: "flying")).isEmpty)
    }

    @Test("term with 3 or fewer characters returns no suggestions")
    func tooShort() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("a b")))
        #expect(Array(fullTextSuggestion(for: partial, searchTerm: "a b")).isEmpty)
    }

    @Test("exact-match content returns no suggestions")
    func exactMatch() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(true, .bare("flies high")))
        #expect(Array(fullTextSuggestion(for: partial, searchTerm: "flies high")).isEmpty)
    }

    @Test("filter content returns no suggestions")
    func filterContent() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("oracle", .including, .bare("flies high")))
        #expect(Array(fullTextSuggestion(for: partial, searchTerm: "flies high")).isEmpty)
    }

    @Test("valid term yields oracle suggestion before flavor suggestion")
    func validTerm() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("flies high")))
        let suggestions = try unwrapFilter(fullTextSuggestion(for: partial, searchTerm: "flies high"))
        #expect(suggestions == [
            .term(.basic(.positive, "oracle", .including, "flies high")),
            .term(.basic(.positive, "flavor", .including, "flies high")),
        ])
    }

    @Test("negative polarity is preserved")
    func negativePolarity() throws {
        let partial = PartialFilterTerm(polarity: .negative, content: .name(false, .bare("flies high")))
        let suggestions = try unwrapFilter(fullTextSuggestion(for: partial, searchTerm: "flies high"))
        #expect(suggestions == [
            .term(.basic(.negative, "oracle", .including, "flies high")),
            .term(.basic(.negative, "flavor", .including, "flies high")),
        ])
    }

    @Test("results have fullText source")
    func source() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("flies high")))
        let suggestions = Array(fullTextSuggestion(for: partial, searchTerm: "flies high"))
        try #require(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { $0.source == .fullText })
    }
}

// MARK: - enumerationSuggestions

private let emptyCatalogData = EnumerationCatalogData(
    catalogs: [:],
    sets: nil,
    artTags: nil,
    oracleTags: nil
)

@Suite
struct EnumerationSuggestionsTests {
    @Test("non-filter content returns no suggestions")
    func nonFilterContent() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("scry")))
        #expect(Array(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("incomplete operator returns no suggestions")
    func incompleteOperator() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("format", .incompleteNotEqual, .bare("")))
        #expect(Array(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("unknown filter type returns no suggestions")
    func unknownFilterType() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("foobar", .including, .bare("")))
        #expect(Array(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("non-enumerable filter type returns no suggestions")
    func nonEnumerable() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("oracle", .equal, .bare("")))
        #expect(Array(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("catalog-backed filter type with no catalog loaded returns no suggestions")
    func catalogBackedWithoutCatalog() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("watermark", .equal, .bare("mir")))
        #expect(Array(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("empty value returns all candidates alphabetically")
    func emptyValue() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("manavalue", .equal, .bare("")))
        let suggestions = try unwrapFilter(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: ""))
        #expect(suggestions == [
            .term(.basic(.positive, "manavalue", .equal, "even")),
            .term(.basic(.positive, "manavalue", .equal, "odd")),
        ])
    }

    @Test("non-matching value returns no suggestions")
    func noMatches() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("is", .including, .bare("zzzzz")))
        #expect(Array(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("matching entries are returned with enumeration source")
    func matchingSource() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("is", .including, .bare("scry")))
        let suggestions = Array(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: ""))
        try #require(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { $0.source == .enumeration })
    }

    @Test("results are ordered by score, best match first")
    func ordering() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("is", .including, .bare("scry")))
        let suggestions = try unwrapFilter(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: ""))
        // "scryland" is shorter and therefore a better match, but both are present
        #expect(suggestions.first == .term(.basic(.positive, "is", .including, "scryland")))
        #expect(suggestions.contains(.term(.basic(.positive, "is", .including, "scryfallpreview"))))
    }

    @Test("negative polarity is preserved")
    func negativePolarity() throws {
        let partial = PartialFilterTerm(polarity: .negative, content: .filter("is", .including, .bare("scry")))
        let suggestions = try unwrapFilter(enumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: ""))
        #expect(suggestions.first == .term(.basic(.negative, "is", .including, "scryland")))
    }

    @Test("catalog watermark values are suggested")
    func catalogWatermark() throws {
        let catalogData = EnumerationCatalogData(
            catalogs: [.watermarks: ["mirran", "phyrexian", "dimir"]],
            sets: nil,
            artTags: nil,
            oracleTags: nil
        )
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("watermark", .equal, .bare("mir")))
        let suggestions = try unwrapFilter(enumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: ""))
        #expect(suggestions == [
            .term(.basic(.positive, "watermark", .equal, "mirran")),
            .term(.basic(.positive, "watermark", .equal, "dimir")),
        ])
    }

    @Test("catalog keyword values are suggested and lowercased")
    func catalogKeyword() throws {
        let catalogData = EnumerationCatalogData(
            catalogs: [.keywordAbilities: ["Flying", "Trample"], .abilityWords: ["Landfall"]],
            sets: nil,
            artTags: nil,
            oracleTags: nil
        )
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("keyword", .equal, .bare("fly")))
        let suggestions = try unwrapFilter(enumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: ""))
        #expect(suggestions == [.term(.basic(.positive, "keyword", .equal, "flying"))])
    }

    @Test("art tag values from catalog are suggested")
    func catalogArtTags() throws {
        let catalogData = EnumerationCatalogData(
            catalogs: [:],
            sets: nil,
            artTags: ["angel", "dragon", "warrior"],
            oracleTags: nil
        )
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("art", .equal, .bare("drag")))
        let suggestions = try unwrapFilter(enumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: ""))
        #expect(suggestions == [.term(.basic(.positive, "art", .equal, "dragon"))])
    }
}

// MARK: - reverseEnumerationSuggestions

@Suite
struct ReverseEnumerationSuggestionsTests {
    @Test("exact-match content returns no suggestions")
    func exactMatch() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(true, .bare("commander")))
        #expect(Array(reverseEnumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("filter content returns no suggestions")
    func filterContent() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("format", .equal, .bare("commander")))
        #expect(Array(reverseEnumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("term shorter than 2 characters returns no suggestions")
    func tooShort() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("c")))
        #expect(Array(reverseEnumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("non-matching term returns no suggestions")
    func noMatches() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("zzzzzz")))
        #expect(Array(reverseEnumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "")).isEmpty)
    }

    @Test("matching entries are returned with reverseEnumeration source")
    func matchingSource() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("commander")))
        let suggestions = Array(reverseEnumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: ""))
        try #require(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { $0.source == .reverseEnumeration })
    }

    @Test("results are ordered by score, best match first")
    func ordering() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("commander")))
        let suggestions = try unwrapFilterParts(reverseEnumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: ""))
        var seen = Set<String>()
        let orderedUniqueValues = suggestions.map(\.value).filter { seen.insert($0).inserted }
        #expect(orderedUniqueValues == ["commander", "duelcommander", "paupercommander"])
    }

    @Test("negative polarity is preserved in results")
    func negativePolarity() throws {
        let partial = PartialFilterTerm(polarity: .negative, content: .name(false, .bare("commander")))
        let suggestions = try unwrapFilterParts(reverseEnumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: ""))
        try #require(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { $0.polarity == .negative })
    }

    @Test("a single value matching multiple filter types produces one result per type")
    func expandsToFilterTypes() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("modern")))
        let suggestions = try unwrapFilterParts(reverseEnumerationSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: ""))
        let modernFilterTypes = Set(suggestions.filter { $0.value == "modern" }.map { $0.filterType.canonicalName })
        #expect(modernFilterTypes == ["format", "banned", "restricted", "cube"])
    }

    @Test("catalog watermark values are matched as bare terms")
    func catalogWatermark() throws {
        let catalogData = EnumerationCatalogData(
            catalogs: [.watermarks: ["mirran", "phyrexian", "dimir"]],
            sets: nil,
            artTags: nil,
            oracleTags: nil
        )
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("mirran")))
        let suggestions = try unwrapFilterParts(reverseEnumerationSuggestions(for: partial, catalogData: catalogData, searchTerm: ""))
        // "mirran" is in the watermark catalog; it also fuzzy-matches "miracle" in the frame filter
        let mirranSuggestions = suggestions.filter { $0.value == "mirran" }
        #expect(mirranSuggestions.map(\.filterType.canonicalName) == ["watermark"])
    }
}

// MARK: - nameSuggestions

@Suite
struct NameSuggestionsTests {
    private let candidates = ["Lightning Bolt", "Firebolt", "Shivan Reef"]

    @Test("non-name filter type returns no suggestions")
    func nonNameFilter() {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("oracle", .including, .bare("bolt")))
        #expect(Array(nameSuggestions(for: partial, in: candidates, searchTerm: "")).isEmpty)
    }

    @Test("term shorter than 2 characters returns no suggestions")
    func tooShort() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("b")))
        #expect(Array(nameSuggestions(for: partial, in: candidates, searchTerm: "")).isEmpty)
    }

    @Test("non-matching term returns no suggestions")
    func noMatches() {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("zzzzz")))
        #expect(Array(nameSuggestions(for: partial, in: candidates, searchTerm: "")).isEmpty)
    }

    @Test("results have name source")
    func matchingSource() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("bolt")))
        let suggestions = Array(nameSuggestions(for: partial, in: candidates, searchTerm: ""))
        try #require(!suggestions.isEmpty)
        #expect(suggestions.allSatisfy { $0.source == .name })
    }

    @Test("results are ordered by score, best match first, non-matching excluded")
    func ordering() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("bolt")))
        let suggestions = try unwrapFilter(nameSuggestions(for: partial, in: candidates, searchTerm: ""))
        #expect(suggestions == [
            .term(.name(.positive, true, "Lightning Bolt")),
            .term(.name(.positive, true, "Firebolt")),
        ])
    }

    @Test("bare name content produces name filter terms")
    func bareNameProducesNameFilter() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .name(false, .bare("bolt")))
        let suggestions = try unwrapFilter(nameSuggestions(for: partial, in: ["Lightning Bolt"], searchTerm: ""))
        #expect(suggestions == [.term(.name(.positive, true, "Lightning Bolt"))])
    }

    @Test("name:= filter content preserves the operator")
    func nameFilterPreservesOperator() throws {
        let partial = PartialFilterTerm(polarity: .positive, content: .filter("name", .equal, .bare("bolt")))
        let suggestions = try unwrapFilter(nameSuggestions(for: partial, in: ["Firebolt"], searchTerm: ""))
        #expect(suggestions == [.term(.basic(.positive, "name", .equal, "Firebolt"))])
    }

    @Test("negative polarity is preserved")
    func negativePolarity() throws {
        let partial = PartialFilterTerm(polarity: .negative, content: .name(false, .bare("bolt")))
        let suggestions = try unwrapFilter(nameSuggestions(for: partial, in: ["Firebolt"], searchTerm: ""))
        #expect(suggestions == [.term(.name(.negative, true, "Firebolt"))])
    }
}

// MARK: - AutocompleteSuggestion.recencyBias

@Suite
struct RecencyBiasTests {
    @Test("gaussian decay curve matches expected values at representative ages")
    func curve() {
        // These tests probably fail around DST (or, as they were written in range of DST, around
        // times that are NOT around DST).
        let epsilon = 0.01
        let samples: [(deltaFromNowInDays: Int, expected: Double)] = [
            (-14, 1.01),
            (-10, 1.07),
            ( -7, 1.19),
            ( -6, 1.25),
            ( -5, 1.31),
            ( -4, 1.37),
            ( -3, 1.42),
            ( -2, 1.46),
            ( -1, 1.49),
            (  0, 1.50),
            (  1, 1.50),
            (  7, 1.50),
        ]
        let actual = samples.map {
            recencyBias(for: Calendar.current.date(byAdding: .day, value: $0.deltaFromNowInDays, to: Date())!)
        }
        let expected = samples.map(\.expected)
        let flooredDeltas = zip(actual, expected).map { abs($0 - $1) < epsilon ? 0 : $0 - $1 }
        #expect(flooredDeltas == samples.map { _ in 0.0 })
    }
}

// MARK: - sortCombinedSuggestions

@Suite
struct SortCombinedSuggestionsTests {
    private func makeSuggestion(
        source: AutocompleteSuggestion.Source = .enumeration,
        filter: FilterQuery<FilterTerm>,
        score: Double,
        biasedScore: Double? = nil
    ) -> AutocompleteSuggestion {
        let text = filter.description
        return AutocompleteSuggestion(
            source: source,
            content: .filter(HighlightedMatch(value: filter, string: text, query: "")),
            rawScore: score,
            biasedScore: biasedScore ?? score
        )
    }

    @Test("empty input returns empty output")
    func empty() {
        #expect(sortCombinedSuggestions([]).isEmpty)
    }

    @Test("results are sorted by score descending")
    func sortsByScore() {
        let high = makeSuggestion(filter: .term(.basic(.positive, "color", .equal, "blue")), score: 0.95)
        let mid = makeSuggestion(filter: .term(.basic(.positive, "color", .equal, "green")), score: 0.9)
        let low = makeSuggestion(filter: .term(.basic(.positive, "color", .equal, "red")), score: 0.8)

        let result = sortCombinedSuggestions([low, high, mid])
        #expect(result.map(\.rawScore) == [0.95, 0.9, 0.8])
    }

    @Test("duplicate content is deduplicated, keeping the higher-scored copy")
    func deduplication() {
        let filter = FilterQuery<FilterTerm>.term(.basic(.positive, "color", .equal, "red"))
        let lower = makeSuggestion(filter: filter, score: 0.8)
        let higher = makeSuggestion(filter: filter, score: 0.95)
        let other = makeSuggestion(filter: .term(.basic(.positive, "color", .equal, "blue")), score: 0.9)

        let result = sortCombinedSuggestions([lower, higher, other])
        #expect(result.map(\.rawScore) == [0.95, 0.9])
    }

    @Test("pinned source bias lifts a lower-scored suggestion above a higher-scored one")
    func pinnedBias() {
        let pinned = makeSuggestion(source: .pinnedFilter, filter: .term(.basic(.positive, "color", .equal, "red")), score: 0.85, biasedScore: 0.85 + 10)
        let other = makeSuggestion(source: .enumeration, filter: .term(.basic(.positive, "color", .equal, "blue")), score: 0.95)

        let result = sortCombinedSuggestions([other, pinned])
        #expect(result.first!.source == .pinnedFilter)
    }

    @Test("history source bias lowers a higher-scored suggestion below a lower-scored one")
    func historyBias() {
        let history = makeSuggestion(source: .historyFilter(Date.now), filter: .term(.basic(.positive, "color", .equal, "red")), score: 0.95, biasedScore: -0.05)
        let other = makeSuggestion(source: .enumeration, filter: .term(.basic(.positive, "color", .equal, "blue")), score: 0.85)

        let result = sortCombinedSuggestions([history, other])
        #expect(result.first!.source == .enumeration)
    }
}
