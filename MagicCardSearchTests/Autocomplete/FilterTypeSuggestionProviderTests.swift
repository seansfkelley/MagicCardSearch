import Testing
@testable import MagicCardSearch

struct FilterTypeSuggestionProviderTests {
    private func extractDisplayNames(_ suggestions: [Suggestion]) -> [String] {
        suggestions.compactMap {
            if case .filterType(let highlighted) = $0.content { highlighted.string } else { nil }
        }
    }

    @Test(
        "getSuggestions",
        arguments: [
            // prefix of a filter returns that filter
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("forma"))),
                ["format"],
            ),
            // substrings matching multiple filters return them all, shortest first
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("print"))),
                ["prints", "paperprints"],
            ),
            // exact match of an alias returns the alias before other matching filters
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("fo"))),
                ["fo", "format"],
            ),
            // unmatching string returns nothing
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("foobar"))),
                [],
            ),
            // negation is included in the result
            (
                PartialFilterTerm(polarity: .negative, content: .name(false, .bare("print"))),
                ["-prints", "-paperprints"],
            ),
            // case-insensitive
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("ForMa"))),
                ["format"],
            ),
            // prefixes are scored higher than other matches, then by length
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("or"))),
                [
                    "order",
                    "oracle",
                    "oracletag",
                    "color",
                    "format",
                    "flavor",
                    "border",
                    "keyword",
                    "fulloracle",
                ],
            ),
            // should prefer the shortest alias
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("ow"))),
                ["pow", "powtou"],
            ),
            // unquoted exact-match is not eligible
            (
                PartialFilterTerm(polarity: .positive, content: .name(true, .bare("form"))),
                [],
            ),
            // quoted exact-match is not eligible
            (
                PartialFilterTerm(polarity: .positive, content: .name(true, .balanced(.doubleQuote, "form"))),
                [],
            ),
            // quoted is not eligible because it implies a name search
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .unterminated(.doubleQuote, "form"))),
                [],
            ),
            // if operators are present we're past the point where we can suggest
            (
                PartialFilterTerm(polarity: .positive, content: .filter("form", .including, .bare(""))),
                [],
            ),
        ]
    )
    func getSuggestions(partial: PartialFilterTerm, expected: [String]) {
        let results = Array(filterTypeSuggestions(for: partial, searchTerm: ""))
        let actualNames = extractDisplayNames(results)
        #expect(actualNames == expected, "\(actualNames) != \(expected)")
        #expect(results.allSatisfy { $0.source == .filterType })
    }
}
