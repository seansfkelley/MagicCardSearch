import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct MagicCardSearchParserTests {
    @Test<[(String, SearchFilter)]>("parse", arguments: [
        ("set:foo", .basic(.keyValue("set", .including, "foo"))),
        ("s=bar", .basic(.keyValue("s", .equal, "bar"))),
        ("mv>=bar", .basic(.keyValue("mv", .greaterThanOrEqual, "bar"))),
        ("'foo'", .basic(.name("foo", false))),
        ("foo:”bar", .basic(.keyValue("foo", .including, "”bar"))), // TODO: Normalize smart quotes.
        ("foo", .basic(.name("foo", false))),
        ("teferi's", .basic(.name("teferi's", false))),
        ("{p}", .basic(.name("{p}", false))),
        ("m>{p/r}{g}", .basic(.keyValue("m", .greaterThan, "{p/r}{g}"))),
        ("!\"Lightning Bolt\"", .basic(.name("Lightning Bolt", true))),
        ("!Fire", .basic(.name("Fire", true))),
        ("Fire!", .basic(.name("Fire!", false))),
        ("filtered:/regex with whitespace/", .basic(.regex("filtered", .including, "/regex with whitespace/"))),
    ])
    func tryParseUnambiguous(input: String, expected: SearchFilter) throws {
        let actual = SearchFilter.tryParseUnambiguous(input)
        #expect(actual == expected)
    }
    
    @Test("from (nil)", arguments: [
        "foo:\"",
        "foo:/incomplete regex",
        "foo: bar",
        "\"foo",
        "'foo",
        "/regexwithoutfilter/",
    ])
    func tryParseUnambiguousNil(input: String) throws {
        #expect(SearchFilter.tryParseUnambiguous(input) == nil)
    }
}

struct SearchFilterTests {
    @Test<[(SearchFilter, String, Range<Int>)]>("toQueryStringWithEditingRange", arguments: [
        (.basic(.keyValue("foo", .including, "bar")), "foo:bar", 4..<7),
        (.negated(.keyValue("foo", .including, "bar")), "-foo:bar", 5..<8),
        (.basic(.regex("foo", .including, "/this is my regex/")), "foo:/this is my regex/", 5..<21),
        (.basic(.name("foo with bar", true)), "!\"foo with bar\"", 2..<14),
    ])
    func toQueryStringWithEditingRange(filter: SearchFilter, expectedString: String, expectedRange: Range<Int>) throws {
        let (actualString, actualRange) = filter.queryStringWithEditingRange
        let range = stringIndexRange(expectedRange)
        #expect(actualString == expectedString)
        #expect(actualRange == range, "wanted highlight on `\(expectedString[range])` but got `\(actualString[actualRange])`")
    }
}
