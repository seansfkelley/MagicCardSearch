import Testing
@testable import MagicCardSearch

func term(_ content: String) -> FilterQuery<PolarityString> {
    .term(.init(.positive, content))
}
func term(_ polarity: Polarity, _ content: String) -> FilterQuery<PolarityString> {
    .term(.init(polarity, content))
}

func and(_ children: FilterQuery<PolarityString>...) -> FilterQuery<PolarityString> {
    .and(.positive, children)
}
func and(_ polarity: Polarity, _ children: FilterQuery<PolarityString>...) -> FilterQuery<PolarityString> {
    .and(polarity, children)
}

func or(_ children: FilterQuery<PolarityString>...) -> FilterQuery<PolarityString> {
    .or(.positive, children)
}
func or(_ polarity: Polarity, _ children: FilterQuery<PolarityString>...) -> FilterQuery<PolarityString> {
    .or(polarity, children)
}

struct TestCase: Sendable, CustomStringConvertible {
    let input: String
    let expectedFilters: [String]
    let expectedParseResult: (PartialFilterQuery, String)?

    var description: String { input }

    init(_ input: String, _ expectedFilters: [String]) {
        self.input = input
        self.expectedFilters = expectedFilters
        self.expectedParseResult = nil
    }
    
    init(_ input: String, _ expectedFilters: [String], _ expectedParseTree: PartialFilterQuery, _ expectedDescription: String) {
        self.input = input
        self.expectedFilters = expectedFilters
        self.expectedParseResult = (expectedParseTree, expectedDescription)
    }
}

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct PartialFilterQueryTests {
    // MARK: - Comprehensive Query Parsing Tests
    
    @Test<[TestCase]>("Parse all query types", arguments: [
        // MARK: Simple Queries
        
        // Single terms
        TestCase(
            "lightning",
            ["lightning"],
            term("lightning"),
            "lightning"
        ),
        
        // Quoted strings (both quote types)
        TestCase(
            "\"lightning bolt\"",
            ["\"lightning bolt\""],
            term("\"lightning bolt\""),
            "\"lightning bolt\""
        ),
        TestCase(
            "'Serra Angel'",
            ["'Serra Angel'"],
            term("'Serra Angel'"),
            "'Serra Angel'"
        ),
        
        // Regex patterns
        TestCase(
            "/^light/",
            ["/^light/"],
            term("/^light/"),
            "/^light/"
        ),
        
        // MARK: AND Queries (Implicit with Whitespace)
        
        // Two terms
        TestCase(
            "lightning bolt",
            ["lightning", "bolt"],
            and(term("lightning"), term("bolt")),
            "lightning bolt"
        ),
        
        // Extra whitespace gets trimmed by lexer
        TestCase(
            "  lightning   bolt    ",
            [" ", "lightning", "bolt", "   "],
            and(term("lightning"), term("bolt")),
            "lightning bolt"
        ),
        
        // MARK: OR Queries
        
        // Two terms
        TestCase(
            "lightning or bolt",
            ["lightning", "or", "bolt"],
            or(term("lightning"), term("bolt")),
            "lightning or bolt"
        ),

        // AND with OR - precedence test
        TestCase(
            "red creature or blue instant",
            ["red", "creature", "or", "blue", "instant"],
            or(and(term("red"), term("creature")), and(term("blue"), term("instant"))),
            "red creature or blue instant"
        ),
        
        // MARK: Parenthesized Queries
        
        // Simple parenthesized - flattened to just the term
        TestCase(
            "(lightning)",
            ["lightning"],
            term("lightning"),
            "lightning"
        ),
        
        // Parenthesized OR
        TestCase(
            "(red or blue)",
            ["red", "or", "blue"],
            or(term("red"), term("blue")),
            "red or blue"
        ),
        
        // Parentheses changing precedence
        TestCase(
            "(red or blue) instant",
            ["red", "or", "blue", "instant"],
            and(or(term("red"), term("blue")), term("instant")),
            "(red or blue) instant"
        ),
        
        // Multiple parenthesized groups - flattens to single OR
        TestCase(
            "(red or blue) or (black or white)",
            ["red", "or", "blue", "or", "black", "or", "white"],
            or(term("red"), term("blue"), term("black"), term("white")),
            "red or blue or black or white"
        ),
        
        // Complex mixed query
        TestCase(
            "(red or blue) creature (flying or haste)",
            ["red", "or", "blue", "creature", "flying", "or", "haste"],
            and(or(term("red"), term("blue")), term("creature"), or(term("flying"), term("haste"))),
            "(red or blue) creature (flying or haste)"
        ),
        
        // Quoted strings in parentheses
        TestCase(
            "(\"lightning bolt\" or \"chain lightning\")",
            ["\"lightning bolt\"", "or", "\"chain lightning\""],
            or(term("\"lightning bolt\""), term("\"chain lightning\"")),
            "\"lightning bolt\" or \"chain lightning\""
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
            term(.negative, "lightning"),
            "-lightning"
        ),

        // Negation with OR and AND
        TestCase(
            "-red or blue",
            ["-red", "or", "blue"],
            or(term(.negative, "red"), term("blue")),
            "-red or blue"
        ),
        
        // Negation in parentheses
        TestCase(
            "(-red)",
            ["-red"],
            term(.negative, "red"),
            "-red"
        ),
        TestCase(
            "(-red or -blue)",
            ["-red", "or", "-blue"],
            or(term(.negative, "red"), term(.negative, "blue")),
            "-red or -blue"
        ),
        TestCase(
            "-(red or blue)",
            ["red", "or", "blue"],
            or(.negative, term("red"), term("blue")),
            "-(red or blue)"
        ),

        // MARK: Key:Value and Comparison Operators
        
        // Simple key:value
        TestCase(
            "name:lightning",
            ["name:lightning"],
            term("name:lightning"),
            "name:lightning"
        ),

        // Comparison operators (representative samples)
        TestCase(
            "power>3",
            ["power>3"],
            term("power>3"),
            "power>3"
        ),
        
        // Mixed with OR and parentheses
        TestCase(
            "name:lightning or name:bolt",
            ["name:lightning", "or", "name:bolt"],
            or(term("name:lightning"), term("name:bolt")),
            "name:lightning or name:bolt"
        ),
        TestCase(
            "(power>=2 or toughness>=3)",
            ["power>=2", "or", "toughness>=3"],
            or(term("power>=2"), term("toughness>=3")),
            "power>=2 or toughness>=3"
        ),
        
        // Mixed with regular terms

        TestCase(
            "((name:lightning) or (name:bolt))",
            ["name:lightning", "or", "name:bolt"],
            or(term("name:lightning"), term("name:bolt")),
            "name:lightning or name:bolt"
        ),
        
        // MARK: Quoted Values
        
        // Double quotes
        TestCase(
            "name:\"lightning bolt\"",
            ["name:\"lightning bolt\""],
            term("name:\"lightning bolt\""),
            "name:\"lightning bolt\""
        ),

        // Single quotes
        TestCase(
            "name:'lightning bolt'",
            ["name:'lightning bolt'"],
            term("name:'lightning bolt'"),
            "name:'lightning bolt'"
        ),
        
        // Mixed quotes with OR and parentheses

        TestCase(
            "(name:\"Serra Angel\" or name:\"Akroma\")",
            ["name:\"Serra Angel\"", "or", "name:\"Akroma\""],
            or(term("name:\"Serra Angel\""), term("name:\"Akroma\"")),
            "name:\"Serra Angel\" or name:\"Akroma\""
        ),
        
        // MARK: Incomplete Terms and Quoted Strings
        
        // Incomplete operators and key:value
        TestCase(
            "power>",
            ["power>"],
            term("power>"),
            "power>"
        ),
        TestCase(
            "name:",
            ["name:"],
            term("name:"),
            "name:"
        ),

        TestCase(
            "(power>) or (name:)",
            ["power>", "or", "name:"],
            or(term("power>"), term("name:")),
            "power> or name:"
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
            term("/^light /end$"),
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
            term(.negative, "name:lightning"),
            "-name:lightning"
        ),

        TestCase(
            "-power>3",
            ["-power>3"],
            term(.negative, "power>3"),
            "-power>3"
        ),

        // Negation with quoted values (various quote types)
        TestCase(
            "-name:\"lightning bolt\"",
            ["-name:\"lightning bolt\""],
            term(.negative, "name:\"lightning bolt\""),
            "-name:\"lightning bolt\""
        ),

        // Incomplete terms with negation
        TestCase(
            "-",
            ["-"],
            term(.negative, ""),
            "-"
        ),

        TestCase(
            "-power>",
            ["-power>"],
            term(.negative, "power>"),
            "-power>"
        ),

        // Nested parentheses with multiple features
        TestCase(
            "((name:lightning or -name:bolt) power>3)",
            ["name:lightning", "or", "-name:bolt", "power>3"],
            and(or(term("name:lightning"), term(.negative, "name:bolt")), term("power>3")),
            "(name:lightning or -name:bolt) power>3"
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
        
        let parsed = PartialFilterQuery.from(testCase.input)
        
        if let (expectedParseTree, expectedDescription) = testCase.expectedParseResult {
            try #require(parsed != nil)
            #expect(parsed == expectedParseTree)
            #expect(parsed!.description == expectedDescription)
        } else {
            #expect(parsed == nil)
        }
    }
}
