import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct PartialFilterQueryLexerTests {
    @Test<[(String, [(String, PartialFilterQueryParser.CitronTokenCode)]?)]>("with allowingUnclosedLiterals=false", arguments: [
        // Apostrophes are not misparsed as single-quotes
        (
            "urza's",
            [("urza's", .Verbatim)],
        ),
        // Unclosed double quote
        (
            "\"lightning ",
            nil,
        ),
    ])
    func allowingUnclosedLiteralsFalse(input: String, expected: [(String, PartialFilterQueryParser.CitronTokenCode)]?) throws {
        let result = try? lexPartialFilterQuery(input, allowingUnclosedLiterals: false)
        if let expected {
            let unwrapped = (try #require(result)).map { ($0.0.content, $0.1) }
            // Explicitly specify the comparison function since the inferred version requires Equatable conformance.
            #expect(unwrapped.elementsEqual(expected, by: ==))
        } else {
            #expect(result == nil)
        }
    }

    @Test<[(String, [(String, PartialFilterQueryParser.CitronTokenCode)]?)]>("with allowingUnclosedLiterals=true", arguments: [
        // Apostrophes are not misparsed as single-quotes
        (
            "urza's",
            [("urza's", .Verbatim)],
        ),
        // Unclosed double quote
        (
            "\"lightning ",
            [("\"lightning ", .Verbatim)],
        ),
    ])
    func allowingUnclosedLiteralsTrue(input: String, expected: [(String, PartialFilterQueryParser.CitronTokenCode)]?) throws {
        let result = try? lexPartialFilterQuery(input, allowingUnclosedLiterals: true)
        if let expected {
            let unwrapped = (try #require(result)).map { ($0.0.content, $0.1) }
            // Explicitly specify the comparison function since the inferred version requires Equatable conformance.
            #expect(unwrapped.elementsEqual(expected, by: ==))
        } else {
            #expect(result == nil)
        }
    }
}
