import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct MagicCardSearchParserTests {
    @Test<[(String, SearchFilter)]>("parse", arguments: [
        ("set:foo", .keyValue("set", .including, "foo")),
        ("s=bar", .keyValue("s", .equal, "bar")),
        ("mv>=bar", .keyValue("mv", .greaterThanOrEqual, "bar")),
        ("'foo'", .name("foo")),
        ("foo:”bar", .keyValue("foo", .including, "”bar")), // TODO: Normalize smart quotes.
    ]) func tryParseUnambiguous(input: String, expected: SearchFilter) throws {
        let actual = SearchFilter.tryParseUnambiguous(input)
        #expect(actual == expected)
    }
    
    @Test("from (nil)", arguments: [
        "foo:\"",
        "foo: bar",
        "'foo",
        "foo",
    ]) func tryParseUnambiguousNil(input: String) throws {
        #expect(SearchFilter.tryParseUnambiguous(input) == nil)
    }
    
}
