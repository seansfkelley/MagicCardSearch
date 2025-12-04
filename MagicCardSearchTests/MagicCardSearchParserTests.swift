import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct MagicCardSearchParserTests {
    @Test<[(String, SearchFilter)]>("parse", arguments: [
        ("set:foo", .init(.set, .colon, "foo")),
        ("s:bar", .init(.set, .colon, "bar")),
    ]) func from(input: String, expected: SearchFilter) throws {
        let actual = SearchFilter.from(input)
        #expect(actual == expected)
    }
    
    @Test("from (nil)", arguments: [

    ]) func fromNil(input: String) throws {
        #expect(SearchFilter.from(input) == nil)
    }
    
}
