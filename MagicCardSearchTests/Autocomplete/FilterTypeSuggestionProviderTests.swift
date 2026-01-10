import Testing
@testable import MagicCardSearch

struct FilterTypeSuggestionProviderTests {
    @Test(
        "getSuggestions",
        arguments: [
            // prefix of a filter returns that filter
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("forma"))),
                [("format", 0..<5)],
            ),
            // substrings matching multiple filters return them all, shortest first
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("print"))),
                [("prints", 0..<5), ("paperprints", 5..<10)],
            ),
            // exact match of an alias returns the alias before other matching filters, and does not return the canonical name
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("fo"))),
                [("fo", 0..<2), ("format", 0..<2)],
            ),
            // unmatching string returns nothing
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("foobar"))),
                [],
            ),
            // negation does not affect the behavior, but is included in the result
            (
                PartialFilterTerm(polarity: .negative, content: .name(false, .bare("print"))),
                [("-prints", 0..<6), ("-paperprints", 6..<11)],
            ),
            // case-insensitive
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("ForMa"))),
                [("format", 0..<5)],
            ),
            // prefixes are scored higher than other matches, even if they're longer, then by length
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("or"))),
                [
                    ("order", 0..<2),
                    ("oracle", 0..<2),
                    ("oracletag", 0..<2),
                    ("color", 3..<5),
                    ("format", 1..<3),
                    ("flavor", 4..<6),
                    ("border", 1..<3),
                    ("keyword", 4..<6),
                    ("fulloracle", 4..<6),
                ],
            ),
            // should prefer the shortest alias, skipping the canonical name, if neither is an exact match
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .bare("ow"))),
                [("pow", 1..<3), ("powtou", 1..<3)],
            ),
            // unquoted exact-match is not eligible even if it would match
            (
                PartialFilterTerm(polarity: .positive, content: .name(true, .bare("form"))),
                [],
            ),
            // quoted exact-match is not eligible even if it would match
            (
                PartialFilterTerm(polarity: .positive, content: .name(true, .balanced(.doubleQuote, "form"))),
                [],
            ),
            // quoted is not eligible because it implies a name search
            (
                PartialFilterTerm(polarity: .positive, content: .name(false, .unterminated(.doubleQuote, "form"))),
                [],
            ),
            // if operators are present we're past the point where we can suggest, even if we could
            (
                PartialFilterTerm(polarity: .positive, content: .filter("form", .including, .bare(""))),
                [],
            ),
        ]
    )
    func getSuggestions(partial: PartialFilterTerm, expected: [(String, Range<Int>)]) {
        let results = FilterTypeSuggestionProvider().getSuggestions(for: partial, limit: Int.max)
        let actualTuples = Array(results.map { ($0.filterType, $0.matchRange) })
        // FIXME: Why can't the compiler figure out that this array of tuples should be equatable?
        #expect(actualTuples.elementsEqual(expected.map { ($0, stringIndexRange($1)) }) { lhs, rhs in
            lhs.0 == rhs.0 && lhs.1 == rhs.1
        }, "\(actualTuples) != \(expected)")
    }
}
