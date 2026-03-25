import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct PartialFilterQueryLexerTests {
    @Test<[(String, [(String, PartialFilterQueryParser.CitronTokenCode)]?)]>("with allowingUnterminatedLiterals=false", arguments: [
        // Apostrophes are not misparsed as single-quotes
        (
            "urza's",
            [("urza's", .Verbatim)],
        ),
        // Unterminated double quote
        (
            "\"lightning ",
            nil,
        ),
    ])
    func allowingUnterminatedLiteralsFalse(input: String, expected: [(String, PartialFilterQueryParser.CitronTokenCode)]?) throws {
        let result = try? lexPartialFilterQuery(input, allowingUnterminatedLiterals: false)
        if let expected {
            let unwrapped = (try #require(result)).map { ($0.0.content, $0.1) }
            // Explicitly specify the comparison function since the inferred version requires Equatable conformance.
            #expect(unwrapped.elementsEqual(expected, by: ==))
        } else {
            #expect(result == nil)
        }
    }

    @Test<[(String, [(String, PartialFilterQueryParser.CitronTokenCode)]?)]>("with allowingUnterminatedLiterals=true", arguments: [
        // Apostrophes are not misparsed as single-quotes
        (
            "urza's",
            [("urza's", .Verbatim)],
        ),
        // Unterminated double quote
        (
            "\"lightning ",
            [("\"lightning ", .Verbatim)],
        ),
    ])
    func allowingUnterminatedLiteralsTrue(input: String, expected: [(String, PartialFilterQueryParser.CitronTokenCode)]?) throws {
        let result = try? lexPartialFilterQuery(input, allowingUnterminatedLiterals: true)
        if let expected {
            let unwrapped = (try #require(result)).map { ($0.0.content, $0.1) }
            // Explicitly specify the comparison function since the inferred version requires Equatable conformance.
            #expect(unwrapped.elementsEqual(expected, by: ==))
        } else {
            #expect(result == nil)
        }
    }
}
