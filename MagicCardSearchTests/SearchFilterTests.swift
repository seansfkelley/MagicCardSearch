import Testing
@testable import MagicCardSearch

@Suite("SearchFilter Tests")
struct SearchFilterTests {
    @Test<[(SearchFilter, String, String)]>(
        "description and suggestedEditingRange",
        arguments: [
            // Simple name without spaces
            (
                .init(.name("lightning", false)),
                "lightning",
                "lightning",
            ),
            // Name with spaces (quoted)
            (
                .init(.name("lightning bolt", false)),
                "\"lightning bolt\"",
                "lightning bolt",
            ),
            // Exact name without spaces
            (
                .init(.name("lightning", true)),
                "!lightning",
                "lightning",
            ),
            // Exact name with spaces (quoted)
            (
                .init(.name("lightning bolt", true)),
                "!\"lightning bolt\"",
                "lightning bolt",
            ),
            // Negated simple name
            (
                .init(true, .name("lightning", false)),
                "-lightning",
                "lightning",
            ),
            // Negated name with spaces
            (
                .init(true, .name("lightning bolt", false)),
                "-\"lightning bolt\"",
                "lightning bolt",
            ),
            // Negated exact name
            (
                .init(true, .name("lightning", true)),
                "-!lightning",
                "lightning",
            ),
            // Key-value without spaces
            (
                .init(.keyValue("color", .equal, "red")),
                "color=red",
                "red",
            ),
            // Key-value with spaces (quoted)
            (
                .init(.keyValue("type", .including, "legendary creature")),
                "type:\"legendary creature\"",
                "legendary creature",
            ),
            // Key-value with different comparison
            (
                .init(.keyValue("power", .greaterThan, "5")),
                "power>5",
                "5",
            ),
            // Negated key-value
            (
                .init(true, .keyValue("color", .equal, "red")),
                "-color=red",
                "red",
            ),
            (
                .init(true, .keyValue("type", .including, "legendary creature")),
                "-type:\"legendary creature\"",
                "legendary creature",
            ),
            // Regex filters
            (
                .init(.regex("oracle", .including, "flying")),
                "oracle:/flying/",
                "flying",
            ),
            (
                .init(.regex("name", .equal, "^lightning")),
                "name=/^lightning/",
                "^lightning",
            ),
            // Negated regex
            (
                .init(true, .regex("oracle", .including, "flying")),
                "-oracle:/flying/",
                "flying",
            ),
            // Parenthesized content
            (
                .init(.disjunction(
                    .init([
                        .init([
                            .filter(SearchFilter(.keyValue("color", .equal, "red"))),
                        ]),
                        .init([
                            .filter(SearchFilter(.keyValue("color", .equal, "blue"))),
                        ]),
                    ])
                )),
                "(color=red or color=blue)",
                "color=red or color=blue",
            ),
            (
                .init(true, .disjunction(
                    .init([
                        .init([
                            .filter(.init(.keyValue("color", .equal, "red"))),
                        ]),
                        .init([
                            .filter(.init(.keyValue("color", .equal, "blue"))),
                        ]),
                    ])
                )),
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
