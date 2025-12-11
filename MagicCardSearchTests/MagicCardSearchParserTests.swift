import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct MagicCardSearchParserTests {
    @Test<[(String, SearchFilter)]>("parse", arguments: [
        ("set:foo", .basic(.keyValue("set", .including, "foo"))),
        ("s=bar", .basic(.keyValue("s", .equal, "bar"))),
        ("mv>=bar", .basic(.keyValue("mv", .greaterThanOrEqual, "bar"))),
        ("'foo'", .basic(.name("foo"))),
        ("foo:”bar", .basic(.keyValue("foo", .including, "”bar"))), // TODO: Normalize smart quotes.
        ("foo", .basic(.name("foo"))),
    ])
    func tryParseUnambiguous(input: String, expected: SearchFilter) throws {
        let actual = SearchFilter.tryParseUnambiguous(input)
        #expect(actual == expected)
    }
    
    @Test("from (nil)", arguments: [
        "foo:\"",
        "foo: bar",
        "'foo",
    ])
    func tryParseUnambiguousNil(input: String) throws {
        #expect(SearchFilter.tryParseUnambiguous(input) == nil)
    }
}

struct SearchFilterTests {
    @Test<[(SearchFilter, String, Range<Int>)]>("toQueryStringWithEditingRange", arguments: [
        (.basic(.keyValue("foo", .including, "bar")), "foo:bar", 4..<7)
    ])
    func toQueryStringWithEditingRange(filter: SearchFilter, string: String, editableRange: Range<Int>) throws {
        let indexRange =
            String.Index.init(encodedOffset: editableRange.lowerBound)
            ..<
            String.Index.init(encodedOffset: editableRange.upperBound)
        #expect(filter.queryStringWithEditingRange == (string, indexRange))
    }
}
