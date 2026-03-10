import Testing
@testable import MagicCardSearch

@Suite
struct StringToFilterTests {
    @Test<[(String, ParsedFilter)]>("String.toFilter()", arguments: [
        (
            "",
            .empty,
        ),
        (
            "   ",
            .empty,
        ),
        (
            "lightning",
            .valid(.term(.name(.positive, false, "lightning"))),
        ),
        (
            "type:creature",
            .valid(.term(.basic(.positive, "type", .including, "creature"))),
        ),
        (
            "-color=red",
            .valid(.term(.basic(.negative, "color", .equal, "red"))),
        ),
        (
            "(type:creature color:green)",
            .valid(.and(.positive, [
                .term(.basic(.positive, "type", .including, "creature")),
                .term(.basic(.positive, "color", .including, "green")),
            ]))
        ),
        (
            "\"lightning",
            .autoterminated(.term(.name(.positive, false, "lightning"))),
        ),
        (
            "oracle:\"draw a card",
            .autoterminated(.term(.basic(.positive, "oracle", .including, "draw a card"))),
        ),
        (
            "type:",
            .fallback(.term(.name(.positive, false, "type:"))),
        ),
        (
            "(lightning",
            .fallback(.term(.name(.positive, false, "(lightning"))),
        ),
        (
            "'urza'",
            .valid(.term(.name(.positive, false, "urza"))),
        ),
    ])
    func toFilter(input: String, expected: ParsedFilter) {
        #expect(input.toFilter() == expected)
    }
}
