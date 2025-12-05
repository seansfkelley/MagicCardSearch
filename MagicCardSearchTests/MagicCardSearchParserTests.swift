import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct MagicCardSearchParserTests {
    @Test<[(String, SearchFilter)]>("parse", arguments: [
        ("set:foo", .init("set", .equal, "foo")),
        ("s=bar", .init("s", .equal, "bar")),
        ("mv>=bar", .init("mv", .greaterThanOrEqual, "bar")),
        ("'foo'", .init("name", .equal, "foo")),
    ]) func from(input: String, expected: SearchFilter) throws {
        let actual = SearchFilter.from(input)
        #expect(actual == expected)
    }
    
    @Test("from (nil)", arguments: [
        "foo: bar",
        "'foo",
    ]) func fromNil(input: String) throws {
        #expect(SearchFilter.from(input) == nil)
    }
    
}
