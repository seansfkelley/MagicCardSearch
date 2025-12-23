import Testing
@testable import MagicCardSearch

@Suite("SearchFilter Tests")
struct SearchFilterTests {
    @Test<[(SearchFilter, String, String)]>(
        "description and suggestedEditingRange",
        arguments: [
            // Simple name without spaces
            (
                SearchFilter.name(false, false, "lightning"),
                "lightning",
                "lightning",
            ),
            // Name with spaces (quoted)
            (
                SearchFilter.name(false, false, "lightning bolt"),
                "\"lightning bolt\"",
                "lightning bolt",
            ),
            // Exact name without spaces
            (
                SearchFilter.name(false, true, "lightning"),
                "!lightning",
                "lightning",
            ),
            // Exact name with spaces (quoted)
            (
                SearchFilter.name(false, true, "lightning bolt"),
                "!\"lightning bolt\"",
                "lightning bolt",
            ),
            // Negated simple name
            (
                SearchFilter.name(true, false, "lightning"),
                "-lightning",
                "lightning",
            ),
            // Negated name with spaces
            (
                SearchFilter.name(true, false, "lightning bolt"),
                "-\"lightning bolt\"",
                "lightning bolt",
            ),
            // Negated exact name
            (
                SearchFilter.name(true, true, "lightning"),
                "-!lightning",
                "lightning",
            ),
            // Key-value without spaces
            (
                SearchFilter.basic(false, "color", .equal, "red"),
                "color=red",
                "red",
            ),
            // Key-value with spaces (quoted)
            (
                SearchFilter.basic(false, "type", .including, "legendary creature"),
                "type:\"legendary creature\"",
                "legendary creature",
            ),
            // Key-value with different comparison
            (
                SearchFilter.basic(false, "power", .greaterThan, "5"),
                "power>5",
                "5",
            ),
            // Negated key-value
            (
                SearchFilter.basic(true, "color", .equal, "red"),
                "-color=red",
                "red",
            ),
            (
                SearchFilter.basic(true, "type", .including, "legendary creature"),
                "-type:\"legendary creature\"",
                "legendary creature",
            ),
            // Regex filters
            (
                SearchFilter.regex(false, "oracle", .including, "flying"),
                "oracle:/flying/",
                "flying",
            ),
            (
                SearchFilter.regex(false, "name", .equal, "^lightning"),
                "name=/^lightning/",
                "^lightning",
            ),
            // Negated regex
            (
                SearchFilter.regex(true, "oracle", .including, "flying"),
                "-oracle:/flying/",
                "flying",
            ),
            // Parenthesized content
            (
                SearchFilter.disjunction(
                    false,
                    [
                        .init([
                            .filter(SearchFilter.basic(false, "color", .equal, "red")),
                        ]),
                        .init([
                            .filter(SearchFilter.basic(true, "color", .equal, "blue")),
                        ]),
                    ],
                ),
                "(color=red or -color=blue)",
                "color=red or -color=blue",
            ),
            (
                SearchFilter.disjunction(
                    true,
                    [
                        .init([
                            .filter(SearchFilter.basic(false, "color", .equal, "red")),
                        ]),
                        .init([
                            .filter(SearchFilter.basic(false, "color", .equal, "blue")),
                        ]),
                    ],
                ),
                "-(color=red or color=blue)",
                "color=red or color=blue",
            ),
        ]
    )
    func descriptionAndSuggestedEditingRange(
        filter: SearchFilter,
        expectedDescription: String,
        expectedEditingContent: String
    ) {
        #expect(filter.description == expectedDescription)

        let description = filter.description
        let editingRange = filter.suggestedEditingRange
        let extractedContent = String(description[editingRange])

        #expect(extractedContent == expectedEditingContent)
    }
}
