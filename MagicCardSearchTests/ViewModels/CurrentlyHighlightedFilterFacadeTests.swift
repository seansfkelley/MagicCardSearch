import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct CurrentlyHighlightedFilterFacadeTests {
    // swiftlint:disable:next large_tuple
    @Test<[(String, Range<Int>, String, Range<Int>?)]>("range and text", arguments: [
        // Empty input
        ("", 0..<0, "", 0..<0),

        // Single filter — point cursor at start, middle, and end
        ("t:creature", 0..<0, "t:creature", 0..<10),
        ("t:creature", 5..<5, "t:creature", 0..<10),
        ("t:creature", 10..<10, "t:creature", 0..<10),

        // Two filters — point cursor in each, and at the space immediately after the first
        ("t:creature c:red", 3..<3, "t:creature", 0..<10),
        ("t:creature c:red", 13..<13, "c:red", 11..<16),
        ("t:creature c:red", 10..<10, "t:creature", 0..<10),

        // Point cursor in the gap between two filters (two spaces, inner space has no adjacent filter)
        ("t:creature  c:red", 11..<11, "", nil),

        // Point cursor at the beginning/end, separated from the filter by one space
        (" t:creature", 0..<0, "", 0..<0),
        ("t:creature ", 11..<11, "", 11..<11),

        // Non-empty selection entirely within a single filter
        ("t:creature", 2..<7, "t:creature", 0..<10),

        // Non-empty selection spanning both filters
        ("t:creature c:red", 5..<13, "", nil),

        // Selection spanning part of first filter and trailing whitespace, not reaching the second filter
        ("t:creature c:red", 5..<11, "", nil),

        // Mirror: selection spanning leading whitespace before second filter and part of that filter
        ("t:creature c:red", 10..<14, "", nil),

        // Same as the trailing-whitespace case, but with two spaces — selection only goes through one
        ("t:creature  c:red", 5..<11, "", nil),

        // Mirror with two spaces — selection only goes through the second space
        ("t:creature  c:red", 11..<15, "", nil),

        // Filter does not include adjacent parentheses
        ("(t:creature c:red)", 5..<5, "t:creature", 1..<11),

        // If adjacent parentheses are included, returns nil
        ("(t:creature c:red)", 0..<5, "", nil),

        // `or` is an operator but might also be the beginning of a filter, so return a range for it
        ("(t:creature or c:red)", 13..<13, "or", 12..<14),
    ])
    func rangeAndText(inputText: String, cursorRange: Range<Int>, expectedText: String, expectedRange: Range<Int>?) throws {
        let facade = CurrentlyHighlightedFilterFacade(
            inputText: inputText,
            inputSelection: try #require(cursorRange.toStringIndices(in: inputText)),
        )
        let expectedStringRange = try expectedRange.map {
            try #require($0.toStringIndices(in: inputText))
        }
        #expect(facade.range == expectedStringRange)
        #expect(facade.text == expectedText)
    }
}
