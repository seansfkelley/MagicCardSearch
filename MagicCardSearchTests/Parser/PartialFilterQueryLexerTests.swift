import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct PartialFilterQueryLexerTests {
    @Test<[(String, [(String, PartialFilterQueryParser.CitronTokenCode)])]>("with allowingUnuterminatedLiterals=true", arguments: [
        // Apostrophes are not misparsed as single-quotes
        (
            "urza's",
            [("urza's", .Verbatim)],
        ),
    ])
    func allowingUnuterminatedLiteralsTrue(input: String, expected: [(String, PartialFilterQueryParser.CitronTokenCode)]) throws {
        let result = try lexPartialFilterQuery(input)
        let unwrapped = result.map { ($0.0.content, $0.1) }
        #expect(unwrapped == expected)
    }
}
