import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct MagicCardSearchParserTests {
    @Test<[(String, SearchFilter)]>("parse", arguments: [
        (
            "foo:bar",
            .init("foo", "bar")
        ),
    ]) func from(input: String, expected: SearchFilter) throws {
        let actual = SearchFilter.from(input)
        #expect(actual == expected)
    }
}
