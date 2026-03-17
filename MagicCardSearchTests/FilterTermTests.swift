import Testing
@testable import MagicCardSearch

@Suite
struct FilterTermTests {
    @Test<[FilterQuery<FilterTerm>]>(
        "isProbablyWellFormedFilter returns true",
        arguments: [
            // name is always well-formed
            .term(.name(.positive, false, "lightning")),
            .term(.name(.negative, true, "lightning bolt")),
            // basic with known filter key
            .term(.basic(.positive, "color", .equal, "red")),
            // basic is case-insensitive on the key
            .term(.basic(.positive, "COLOR", .equal, "red")),
            // regex on a field that supports it, with : or =
            .term(.regex(.positive, "oracle", .including, "flying")),
            .term(.regex(.positive, "name", .equal, "^lightning")),
            // compound queries delegate to their children
            .and(.positive, [
                .term(.basic(.positive, "color", .equal, "red")),
                .term(.name(.positive, false, "bolt")),
            ]),
            .or(.positive, [
                .term(.basic(.positive, "color", .equal, "red")),
                .term(.name(.positive, false, "bolt")),
            ]),
        ]
    )
    func isProbablyWellFormedFilterTrue(filter: FilterQuery<FilterTerm>) {
        #expect(filter.isProbablyWellFormedFilter)
    }

    @Test<[FilterQuery<FilterTerm>]>(
        "isProbablyWellFormedFilter returns false",
        arguments: [
            // basic with unknown filter key
            .term(.basic(.positive, "notafilter", .equal, "value")),
            // regex on a field that doesn't support regex
            .term(.regex(.positive, "color", .including, "red")),
            // regex on an unknown field
            .term(.regex(.positive, "notafilter", .including, "value")),
            // regex with an unsupported comparison operator
            .term(.regex(.positive, "oracle", .greaterThan, "flying")),
            // compound queries fail if any child is ill-formed
            .and(.positive, [
                .term(.basic(.positive, "color", .equal, "red")),
                .term(.basic(.positive, "notafilter", .equal, "value")),
            ]),
            .or(.positive, [
                .term(.basic(.positive, "color", .equal, "red")),
                .term(.basic(.positive, "notafilter", .equal, "value")),
            ]),
        ]
    )
    func isProbablyWellFormedFilterFalse(filter: FilterQuery<FilterTerm>) {
        #expect(!filter.isProbablyWellFormedFilter)
    }

    @Test<[(FilterTerm, String, String)]>(
        "description and suggestedEditingRange",
        arguments: [
            // Simple name without spaces
            (
                FilterTerm.name(.positive, false, "lightning"),
                "lightning",
                "lightning",
            ),
            // Name with spaces (quoted)
            (
                FilterTerm.name(.positive, false, "lightning bolt"),
                "\"lightning bolt\"",
                "lightning bolt",
            ),
            // Exact name without spaces
            (
                FilterTerm.name(.positive, true, "lightning"),
                "!lightning",
                "lightning",
            ),
            // Exact name with spaces (quoted)
            (
                FilterTerm.name(.positive, true, "lightning bolt"),
                "!\"lightning bolt\"",
                "lightning bolt",
            ),
            // Negated simple name
            (
                FilterTerm.name(.negative, false, "lightning"),
                "-lightning",
                "lightning",
            ),
            // Negated name with spaces
            (
                FilterTerm.name(.negative, false, "lightning bolt"),
                "-\"lightning bolt\"",
                "lightning bolt",
            ),
            // Negated exact name
            (
                FilterTerm.name(.negative, true, "lightning"),
                "-!lightning",
                "lightning",
            ),
            // Key-value without spaces
            (
                FilterTerm.basic(.positive, "color", .equal, "red"),
                "color=red",
                "red",
            ),
            // Key-value with spaces (quoted)
            (
                FilterTerm.basic(.positive, "type", .including, "legendary creature"),
                "type:\"legendary creature\"",
                "legendary creature",
            ),
            // Key-value with different comparison
            (
                FilterTerm.basic(.positive, "power", .greaterThan, "5"),
                "power>5",
                "5",
            ),
            // Negated key-value
            (
                FilterTerm.basic(.negative, "color", .equal, "red"),
                "-color=red",
                "red",
            ),
            (
                FilterTerm.basic(.negative, "type", .including, "legendary creature"),
                "-type:\"legendary creature\"",
                "legendary creature",
            ),
            // Regex filters
            (
                FilterTerm.regex(.positive, "oracle", .including, "flying"),
                "oracle:/flying/",
                "flying",
            ),
            (
                FilterTerm.regex(.positive, "name", .equal, "^lightning"),
                "name=/^lightning/",
                "^lightning",
            ),
            // Negated regex
            (
                FilterTerm.regex(.negative, "oracle", .including, "flying"),
                "-oracle:/flying/",
                "flying",
            ),
        ]
    )
    func descriptionAndSuggestedEditingRange(
        filter: FilterTerm,
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
