import Testing
@testable import MagicCardSearch

private func term(_ content: String) -> PartialFilterQuery {
    .term(.init(.positive, content))
}
private func term(_ polarity: Polarity, _ content: String) -> PartialFilterQuery {
    .term(.init(polarity, content))
}

private func and(_ children: PartialFilterQuery...) -> PartialFilterQuery {
    .and(.positive, children)
}
private func and(_ polarity: Polarity, _ children: PartialFilterQuery...) -> PartialFilterQuery {
    .and(polarity, children)
}

private func or(_ children: PartialFilterQuery...) -> PartialFilterQuery {
    .or(.positive, children)
}
private func or(_ polarity: Polarity, _ children: PartialFilterQuery...) -> PartialFilterQuery {
    .or(polarity, children)
}

struct TestCase: Sendable, CustomStringConvertible {
    let input: String
    let expectedFilters: [String]
    let expectedBestParse: PartialFilterQuery.BestParse?
    let expectedDescription: String?

    var description: String { input }

    init(_ input: String, _ expectedFilters: [String]) {
        self.input = input
        self.expectedFilters = expectedFilters
        self.expectedBestParse = nil
        self.expectedDescription = nil
    }

    init(_ input: String, _ expectedFilters: [String], _ expectedBestParse: PartialFilterQuery.BestParse, _ expectedDescription: String) {
        self.input = input
        self.expectedFilters = expectedFilters
        self.expectedBestParse = expectedBestParse
        self.expectedDescription = expectedDescription
    }
}

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct PartialFilterQueryBestParseTests {
    // MARK: - Comprehensive Query Parsing Tests

    @Test<[TestCase]>("Parse all query types", arguments: [
        // MARK: Simple Queries

        // Single terms
        TestCase(
            "lightning",
            ["lightning"],
            .valid(term("lightning")),
            "lightning"
        ),

        // Quoted strings (both quote types)
        TestCase(
            "\"lightning bolt\"",
            ["\"lightning bolt\""],
            .valid(term("\"lightning bolt\"")),
            "\"lightning bolt\""
        ),
        TestCase(
            "'Serra Angel'",
            ["'Serra Angel'"],
            .valid(term("'Serra Angel'")),
            "'Serra Angel'"
        ),

        // Regex patterns
        TestCase(
            "/^light/",
            ["/^light/"],
            .valid(term("/^light/")),
            "/^light/"
        ),

        // MARK: AND Queries (Implicit with Whitespace)

        // Two terms
        TestCase(
            "lightning bolt",
            ["lightning", "bolt"],
            .valid(and(term("lightning"), term("bolt"))),
            "(lightning bolt)"
        ),

        // Extra whitespace gets trimmed by lexer
        TestCase(
            "  lightning   bolt    ",
            [" ", "lightning", "bolt", "   "],
            .valid(and(term("lightning"), term("bolt"))),
            "(lightning bolt)"
        ),

        // MARK: OR Queries

        // Two terms
        TestCase(
            "lightning or bolt",
            ["lightning", "or", "bolt"],
            .valid(or(term("lightning"), term("bolt"))),
            "(lightning or bolt)"
        ),

        // AND with OR - precedence test
        TestCase(
            "red creature or blue instant",
            ["red", "creature", "or", "blue", "instant"],
            .valid(or(and(term("red"), term("creature")), and(term("blue"), term("instant")))),
            "(red creature or blue instant)"
        ),

        // MARK: Parenthesized Queries

        // Simple parenthesized - flattened to just the term
        TestCase(
            "(lightning)",
            ["lightning"],
            .valid(term("lightning")),
            "lightning"
        ),

        // Parenthesized OR
        TestCase(
            "(red or blue)",
            ["red", "or", "blue"],
            .valid(or(term("red"), term("blue"))),
            "(red or blue)"
        ),

        // Parentheses changing precedence
        TestCase(
            "(red or blue) instant",
            ["red", "or", "blue", "instant"],
            .valid(and(or(term("red"), term("blue")), term("instant"))),
            "((red or blue) instant)"
        ),

        // Multiple parenthesized groups - flattens to single OR
        TestCase(
            "(red or blue) or (black or white)",
            ["red", "or", "blue", "or", "black", "or", "white"],
            .valid(or(term("red"), term("blue"), term("black"), term("white"))),
            "(red or blue or black or white)"
        ),

        // Complex mixed query
        TestCase(
            "(red or blue) creature (flying or haste)",
            ["red", "or", "blue", "creature", "flying", "or", "haste"],
            .valid(and(or(term("red"), term("blue")), term("creature"), or(term("flying"), term("haste")))),
            "((red or blue) creature (flying or haste))"
        ),

        // Quoted strings in parentheses
        TestCase(
            "(\"lightning bolt\" or \"chain lightning\")",
            ["\"lightning bolt\"", "or", "\"chain lightning\""],
            .valid(or(term("\"lightning bolt\""), term("\"chain lightning\""))),
            "(\"lightning bolt\" or \"chain lightning\")"
        ),

        // MARK: Edge Cases

        // Empty and whitespace
        TestCase(
            "()",
            [],
        ),

        // Unclosed parentheses
        TestCase(
            "(red or blue",
            ["red", "or", "blue"],
        ),

        // Unmatched closing parenthesis
        TestCase(
            "red or blue)",
            ["red", "or", "blue"],
        ),

        // OR at end - gets ignored
        TestCase(
            "red or",
            ["red", "or"],
        ),

        // MARK: Negation

        // Simple negation
        TestCase(
            "-lightning",
            ["-lightning"],
            .valid(term(.negative, "lightning")),
            "-lightning"
        ),

        // Negation with OR and AND
        TestCase(
            "-red or blue",
            ["-red", "or", "blue"],
            .valid(or(term(.negative, "red"), term("blue"))),
            "(-red or blue)"
        ),

        // Negation in parentheses
        TestCase(
            "(-red)",
            ["-red"],
            .valid(term(.negative, "red")),
            "-red"
        ),
        TestCase(
            "(-red or -blue)",
            ["-red", "or", "-blue"],
            .valid(or(term(.negative, "red"), term(.negative, "blue"))),
            "(-red or -blue)"
        ),
        TestCase(
            "-(red or blue)",
            ["red", "or", "blue"],
            .valid(or(.negative, term("red"), term("blue"))),
            "-(red or blue)"
        ),

        // MARK: Key:Value and Comparison Operators

        // Simple key:value
        TestCase(
            "name:lightning",
            ["name:lightning"],
            .valid(term("name:lightning")),
            "name:lightning"
        ),

        // Comparison operators (representative samples)
        TestCase(
            "power>3",
            ["power>3"],
            .valid(term("power>3")),
            "power>3"
        ),

        // Mixed with OR and parentheses
        TestCase(
            "name:lightning or name:bolt",
            ["name:lightning", "or", "name:bolt"],
            .valid(or(term("name:lightning"), term("name:bolt"))),
            "(name:lightning or name:bolt)"
        ),
        TestCase(
            "(power>=2 or toughness>=3)",
            ["power>=2", "or", "toughness>=3"],
            .valid(or(term("power>=2"), term("toughness>=3"))),
            "(power>=2 or toughness>=3)"
        ),

        // Mixed with regular terms

        TestCase(
            "((name:lightning) or (name:bolt))",
            ["name:lightning", "or", "name:bolt"],
            .valid(or(term("name:lightning"), term("name:bolt"))),
            "(name:lightning or name:bolt)"
        ),

        // MARK: Quoted Values

        // Double quotes
        TestCase(
            "name:\"lightning bolt\"",
            ["name:\"lightning bolt\""],
            .valid(term("name:\"lightning bolt\"")),
            "name:\"lightning bolt\""
        ),

        // Single quotes
        TestCase(
            "name:'lightning bolt'",
            ["name:'lightning bolt'"],
            .valid(term("name:'lightning bolt'")),
            "name:'lightning bolt'"
        ),

        // Mixed quotes with OR and parentheses

        TestCase(
            "(name:\"Serra Angel\" or name:\"Akroma\")",
            ["name:\"Serra Angel\"", "or", "name:\"Akroma\""],
            .valid(or(term("name:\"Serra Angel\""), term("name:\"Akroma\""))),
            "(name:\"Serra Angel\" or name:\"Akroma\")"
        ),

        // MARK: Incomplete Terms and Quoted Strings

        // Incomplete operators and key:value
        TestCase(
            "power>",
            ["power>"],
            .valid(term("power>")),
            "power>"
        ),
        TestCase(
            "name:",
            ["name:"],
            .valid(term("name:")),
            "name:"
        ),

        TestCase(
            "(power>) or (name:)",
            ["power>", "or", "name:"],
            .valid(or(term("power>"), term("name:"))),
            "(power> or name:)"
        ),

        // Unclosed double quotes - these consume everything after including whitespace
        TestCase(
            "name:\"lightning  ",
            ["name:\"lightning  "]
        ),

        // Unclosed single quotes
        TestCase(
            "name:'lightning  ",
            ["name:'lightning  "]
        ),

        // Unclosed quotes in parentheses - closing paren becomes part of the string
        TestCase(
            "(name:\"lightning)",
            ["name:\"lightning)"]
        ),

        // MARK: Incomplete Regex Patterns

        // Unclosed regex - these consume everything including whitespace
        TestCase(
            "/^light",
            ["/^light"]
        ),

        // Multiple unclosed regex
        TestCase(
            "/^light /end$",
            ["/^light /end$"],
            .valid(term("/^light /end$")),
            "/^light /end$"
        ),

        // MARK: Nested and Incomplete Parentheses

        // Unclosed single level
        TestCase(
            "(red",
            ["red"]
        ),

        // Unclosed nested
        TestCase(
            "((red)",
            ["red"]
        ),

        // Extra closing parentheses
        TestCase(
            "red)",
            ["red"]
        ),

        // Empty unclosed parentheses
        TestCase(
            "(",
            [""]
        ),
        TestCase(
            ") red",
            ["", "red"]
        ),
        TestCase(
            "red (",
            ["red", ""]
        ),

        // MARK: Complex Combinations

        // Negation with key:value and comparisons
        TestCase(
            "-name:lightning",
            ["-name:lightning"],
            .valid(term(.negative, "name:lightning")),
            "-name:lightning"
        ),

        TestCase(
            "-power>3",
            ["-power>3"],
            .valid(term(.negative, "power>3")),
            "-power>3"
        ),

        // Negation with quoted values (various quote types)
        TestCase(
            "-name:\"lightning bolt\"",
            ["-name:\"lightning bolt\""],
            .valid(term(.negative, "name:\"lightning bolt\"")),
            "-name:\"lightning bolt\""
        ),

        // Incomplete terms with negation
        TestCase(
            "-",
            ["-"],
            .valid(term(.negative, "")),
            "-"
        ),

        TestCase(
            "-power>",
            ["-power>"],
            .valid(term(.negative, "power>")),
            "-power>"
        ),

        // Nested parentheses with multiple features
        TestCase(
            "((name:lightning or -name:bolt) power>3)",
            ["name:lightning", "or", "-name:bolt", "power>3"],
            .valid(and(or(term("name:lightning"), term(.negative, "name:bolt")), term("power>3"))),
            "((name:lightning or -name:bolt) power>3)"
        ),

        // Incomplete nested with mixed quotes and operators
        TestCase(
            "((name:\"lightning power>3",
            ["name:\"lightning power>3"]
        ),
        TestCase(
            "name:'bolt type:creature",
            ["name:'bolt type:creature"]
        ),
        TestCase(
            "   ",
            []
        ),

        TestCase(
            "or red",
            ["or", "red"]
        ),
        TestCase(
            "red or or blue",
            ["red", "or", "or", "blue"]
        ),
    ])
    func parseAllQueryTypes(_ testCase: TestCase) throws {
        let materializedRanges = PlausibleFilterRanges.from(testCase.input).ranges.map { String(testCase.input[$0]) }
        #expect(materializedRanges == testCase.expectedFilters)

        let result = PartialFilterQuery.from(testCase.input)
        if let expectedBestParse = testCase.expectedBestParse {
            #expect(result == expectedBestParse)
            if let expectedDescription = testCase.expectedDescription {
                #expect(result.value?.description == expectedDescription)
            }
        } else {
            #expect(result == nil)
        }
    }
}
