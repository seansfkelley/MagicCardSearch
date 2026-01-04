import Testing
@testable import MagicCardSearch

private func disj(_ negated: Bool, conjs: ParenthesizedConjunction...) -> ParenthesizedDisjunction {
    .init(negated, conjs)
}

private func disj(_ conjs: ParenthesizedConjunction...) -> ParenthesizedDisjunction {
    .init(false, conjs)
}

private func conj(_ clauses: ParenthesizedConjunction.Clause...) -> ParenthesizedConjunction {
    .init(clauses)
}

struct TestCase: Sendable, CustomStringConvertible {
    let input: String
    let expectedFilters: [String]
    let expectedParseResult: (ParenthesizedDisjunction, String)?

    var description: String { input }

    init(_ input: String, _ expectedFilters: [String]) {
        self.input = input
        self.expectedFilters = expectedFilters
        self.expectedParseResult = nil
    }
    
    init(_ input: String, _ expectedFilters: [String], _ expectedParseTree: ParenthesizedDisjunction, _ expectedDescription: String) {
        self.input = input
        self.expectedFilters = expectedFilters
        self.expectedParseResult = (expectedParseTree, expectedDescription)
    }
}

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct ParenthesizedQueryTests {
    // MARK: - Comprehensive Query Parsing Tests
    
    @Test<[TestCase]>("Parse all query types", arguments: [
        // MARK: Simple Queries
        
        // Single terms
        TestCase(
            "lightning",
            ["lightning"],
            disj(
                conj(
                    .filter("lightning"),
                ),
            ),
            "lightning",
        ),
        
        // Quoted strings (both quote types)
        TestCase(
            "\"lightning bolt\"",
            ["\"lightning bolt\""],
            disj(
                conj(
                    .filter("\"lightning bolt\""),
                ),
            ),
            "\"lightning bolt\"",
        ),
        TestCase(
            "'Serra Angel'",
            ["'Serra Angel'"],
            disj(
                conj(
                    .filter("'Serra Angel'"),
                ),
            ),
            "'Serra Angel'",
        ),
        
        // Regex patterns
        TestCase(
            "/^light/",
            ["/^light/"],
            disj(
                conj(
                    .filter("/^light/"),
                ),
            ),
            "/^light/",
        ),
        
        // MARK: AND Queries (Implicit with Whitespace)
        
        // Two terms
        TestCase(
            "lightning bolt",
            ["lightning", "bolt"],
            disj(
                conj(
                    .filter("lightning"),
                    .filter("bolt"),
                ),
            ),
            "lightning bolt",
        ),
        
        // Extra whitespace gets trimmed by lexer
        TestCase(
            "  lightning   bolt    ",
            [" ", "lightning", "bolt", "   "],
            disj(
                conj(
                    .filter("lightning"),
                    .filter("bolt"),
                ),
            ),
            "lightning bolt",
        ),
        
        // MARK: OR Queries
        
        // Two terms
        TestCase(
            "lightning or bolt",
            ["lightning", "or", "bolt"],
            disj(
                conj(
                    .filter("lightning"),
                ),
                conj(
                    .filter("bolt"),
                ),
            ),
            "lightning or bolt",
        ),

        // AND with OR - precedence test
        TestCase(
            "red creature or blue instant",
            ["red", "creature", "or", "blue", "instant"],
            disj(
                conj(
                    .filter("red"),
                    .filter("creature"),
                ),
                conj(
                    .filter("blue"),
                    .filter("instant"),
                ),
            ),
            "red creature or blue instant",
        ),
        
        // MARK: Parenthesized Queries
        
        // Simple parenthesized
        TestCase(
            "(lightning)",
            ["lightning"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("lightning"),
                            ),
                        ),
                    ),
                ),
            ),
            "lightning",
        ),
        
        // Parenthesized OR
        TestCase(
            "(red or blue)",
            ["red", "or", "blue"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("red"),
                            ),
                            conj(
                                .filter("blue"),
                            ),
                        ),
                    ),
                ),
            ),
            "red or blue",
        ),
        
        // Parentheses changing precedence
        TestCase(
            "(red or blue) instant",
            ["red", "or", "blue", "instant"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("red"),
                            ),
                            conj(
                                .filter("blue"),
                            ),
                        ),
                    ),
                    .filter("instant"),
                ),
            ),
            "(red or blue) instant",
        ),
        
        // Multiple parenthesized groups
        TestCase(
            "(red or blue) or (black or white)",
            ["red", "or", "blue", "or", "black", "or", "white"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("red"),
                            ),
                            conj(
                                .filter("blue"),
                            ),
                        ),
                    ),
                ),
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("black"),
                            ),
                            conj(
                                .filter("white"),
                            ),
                        ),
                    ),
                ),
            ),
            "red or blue or black or white",
        ),
        
        // Complex mixed query
        TestCase(
            "(red or blue) creature (flying or haste)",
            ["red", "or", "blue", "creature", "flying", "or", "haste"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("red"),
                            ),
                            conj(
                                .filter("blue"),
                            ),
                        ),
                    ),
                    .filter("creature"),
                    .disjunction(
                        disj(
                            conj(
                                .filter("flying"),
                            ),
                            conj(
                                .filter("haste"),
                            ),
                        ),
                    ),
                ),
            ),
            "(red or blue) creature (flying or haste)",
        ),
        
        // Quoted strings in parentheses
        TestCase(
            "(\"lightning bolt\" or \"chain lightning\")",
            ["\"lightning bolt\"", "or", "\"chain lightning\""],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("\"lightning bolt\""),
                            ),
                            conj(
                                .filter("\"chain lightning\""),
                            ),
                        ),
                    ),
                ),
            ),
            "\"lightning bolt\" or \"chain lightning\"",
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
            disj(
                conj(
                    .filter("-lightning"),
                ),
            ),
            "-lightning",
        ),

        // Negation with OR and AND
        TestCase(
            "-red or blue",
            ["-red", "or", "blue"],
            disj(
                conj(
                    .filter("-red"),
                ),
                conj(
                    .filter("blue"),
                ),
            ),
            "-red or blue",
        ),
        
        // Negation in parentheses
        TestCase(
            "(-red)",
            ["-red"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("-red"),
                            ),
                        ),
                    ),
                ),
            ),
            "-red",
        ),
        TestCase(
            "(-red or -blue)",
            ["-red", "or", "-blue"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("-red"),
                            ),
                            conj(
                                .filter("-blue"),
                            ),
                        ),
                    ),
                ),
            ),
            "-red or -blue",
        ),
        
        // MARK: Key:Value and Comparison Operators
        
        // Simple key:value
        TestCase(
            "name:lightning",
            ["name:lightning"],
            disj(
                conj(
                    .filter("name:lightning"),
                ),
            ),
            "name:lightning",
        ),

        // Comparison operators (representative samples)
        TestCase(
            "power>3",
            ["power>3"],
            disj(
                conj(
                    .filter("power>3"),
                ),
            ),
            "power>3",
        ),
        
        // Mixed with OR and parentheses
        TestCase(
            "name:lightning or name:bolt",
            ["name:lightning", "or", "name:bolt"],
            disj(
                conj(
                    .filter("name:lightning"),
                ),
                conj(
                    .filter("name:bolt"),
                ),
            ),
            "name:lightning or name:bolt",
        ),
        TestCase(
            "(power>=2 or toughness>=3)",
            ["power>=2", "or", "toughness>=3"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("power>=2"),
                            ),
                            conj(
                                .filter("toughness>=3"),
                            ),
                        ),
                    ),
                ),
            ),
            "power>=2 or toughness>=3",
        ),
        
        // Mixed with regular terms

        TestCase(
            "((name:lightning) or (name:bolt))",
            ["name:lightning", "or", "name:bolt"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .disjunction(
                                    disj(
                                        conj(
                                            .filter("name:lightning"),
                                        ),
                                    ),
                                ),
                            ),
                            conj(
                                .disjunction(
                                    disj(
                                        conj(
                                            .filter("name:bolt"),
                                        ),
                                    ),
                                ),
                            ),
                        ),
                    ),
                ),
            ),
            "name:lightning or name:bolt",
        ),
        
        // MARK: Quoted Values
        
        // Double quotes
        TestCase(
            "name:\"lightning bolt\"",
            ["name:\"lightning bolt\""],
            disj(
                conj(
                    .filter("name:\"lightning bolt\""),
                ),
            ),
            "name:\"lightning bolt\"",
        ),

        // Single quotes
        TestCase(
            "name:'lightning bolt'",
            ["name:'lightning bolt'"],
            disj(
                conj(
                    .filter("name:'lightning bolt'"),
                ),
            ),
            "name:'lightning bolt'",
        ),
        
        // Mixed quotes with OR and parentheses

        TestCase(
            "(name:\"Serra Angel\" or name:\"Akroma\")",
            ["name:\"Serra Angel\"", "or", "name:\"Akroma\""],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("name:\"Serra Angel\""),
                            ),
                            conj(
                                .filter("name:\"Akroma\""),
                            ),
                        ),
                    ),
                ),
            ),
            "name:\"Serra Angel\" or name:\"Akroma\"",
        ),
        
        // MARK: Incomplete Terms and Quoted Strings
        
        // Incomplete operators and key:value
        TestCase(
            "power>",
            ["power>"],
            disj(
                conj(
                    .filter("power>"),
                ),
            ),
            "power>",
        ),
        TestCase(
            "name:",
            ["name:"],
            disj(
                conj(
                    .filter("name:"),
                ),
            ),
            "name:",
        ),

        TestCase(
            "(power>) or (name:)",
            ["power>", "or", "name:"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("power>"),
                            ),
                        ),
                    ),
                ),
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .filter("name:"),
                            ),
                        ),
                    ),
                ),
            ),
            "power> or name:",
        ),
        
        // Unclosed double quotes - these consume everything after including whitespace
        TestCase(
            "name:\"lightning  ",
            ["name:\"lightning  "],
        ),

        // Unclosed single quotes
        TestCase(
            "name:'lightning  ",
            ["name:'lightning  "],
        ),

        // Unclosed quotes in parentheses - closing paren becomes part of the string
        TestCase(
            "(name:\"lightning)",
            ["name:\"lightning)"],
        ),

        // MARK: Incomplete Regex Patterns
        
        // Unclosed regex - these consume everything including whitespace
        TestCase(
            "/^light",
            ["/^light"],
        ),

        // Multiple unclosed regex
        TestCase(
            "/^light /end$",
            ["/^light /end$"],
            disj(
                conj(
                    .filter("/^light /end$"),
                ),
            ),
            "/^light /end$",
        ),
        
        // MARK: Nested and Incomplete Parentheses
        
        // Unclosed single level
        TestCase(
            "(red",
            ["red"],
        ),
        
        // Unclosed nested
        TestCase(
            "((red)",
            ["red"],
        ),
        
        // Extra closing parentheses
        TestCase(
            "red)",
            ["red"],
        ),
        
        // Empty unclosed parentheses
        TestCase(
            "(",
            [""],
        ),
        TestCase(
            ") red",
            ["", "red"],
        ),
        TestCase(
            "red (",
            ["red", ""],
        ),
        
        // MARK: Complex Combinations
        
        // Negation with key:value and comparisons
        TestCase(
            "-name:lightning",
            ["-name:lightning"],
            disj(
                conj(
                    .filter("-name:lightning"),
                ),
            ),
            "-name:lightning",
        ),

        TestCase(
            "-power>3",
            ["-power>3"],
            disj(
                conj(
                    .filter("-power>3"),
                ),
            ),
            "-power>3",
        ),

        // Negation with quoted values (various quote types)
        TestCase(
            "-name:\"lightning bolt\"",
            ["-name:\"lightning bolt\""],
            disj(
                conj(
                    .filter("-name:\"lightning bolt\""),
                ),
            ),
            "-name:\"lightning bolt\"",
        ),

        // Incomplete terms with negation
        TestCase(
            "-",
            ["-"],
            disj(
                conj(
                    .filter("-"),
                ),
            ),
            "-",
        ),

        TestCase(
            "-power>",
            ["-power>"],
            disj(
                conj(
                    .filter("-power>"),
                ),
            ),
            "-power>",
        ),

        // Nested parentheses with multiple features
        TestCase(
            "((name:lightning or -name:bolt) power>3)",
            ["name:lightning", "or", "-name:bolt", "power>3"],
            disj(
                conj(
                    .disjunction(
                        disj(
                            conj(
                                .disjunction(
                                    disj(
                                        conj(
                                            .filter("name:lightning"),
                                        ),
                                        conj(
                                            .filter("-name:bolt"),
                                        ),
                                    ),
                                ),
                                .filter("power>3"),
                            ),
                        ),
                    ),
                ),
            ),
            "(name:lightning or -name:bolt) power>3",
        ),
        
        // Incomplete nested with mixed quotes and operators
        TestCase(
            "((name:\"lightning power>3",
            ["name:\"lightning power>3"],
        ),
        TestCase(
            "name:'bolt type:creature",
            ["name:'bolt type:creature"],
        ),
        TestCase(
            "   ",
            [],
        ),

        TestCase(
            "or red",
            ["or", "red"],
        ),
        TestCase(
            "red or or blue",
            ["red", "or", "or", "blue"],
        ),
    ])
    func parseAllQueryTypes(_ testCase: TestCase) throws {
        let materializedRanges = PlausibleFilterRanges.from(testCase.input).ranges.map { String(testCase.input[$0]) }
        #expect(materializedRanges == testCase.expectedFilters)
        
        let parsed = ParenthesizedDisjunction.tryParse(testCase.input)
        
        if let (expectedParseTree, expectedDescription) = testCase.expectedParseResult {
            try #require(parsed != nil)
            #expect(parsed == expectedParseTree)
            #expect(parsed!.description == expectedDescription)
        } else {
            #expect(parsed == nil)
        }
    }
}
