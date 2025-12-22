//
//  ParenthesizedQueryTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//

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

struct TestCase: Sendable {
    let input: String
    let expectedFilters: [String]
    let expectedParseResult: (ParenthesizedDisjunction, String)?
    
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
        
        // Quoted strings
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
        
        // Multiple terms
        TestCase(
            "red creature haste",
            ["red", "creature", "haste"],
            disj(
                conj(
                    .filter("red"),
                    .filter("creature"),
                    .filter("haste"),
                ),
            ),
            "red creature haste",
        ),
        
        // Extra whitespace gets trimmed by lexer
        TestCase(
            "  lightning   bolt  ",
            ["lightning", "bolt"],
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
            ["lightning", "bolt"],
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
        
        // Multiple terms
        TestCase(
            "red or blue or green",
            ["red", "blue", "green"],
            disj(
                conj(
                    .filter("red"),
                ),
                conj(
                    .filter("blue"),
                ),
                conj(
                    .filter("green"),
                ),
            ),
            "red or blue or green",
        ),
        
        // AND with OR - precedence test
        TestCase(
            "red creature or blue instant",
            ["red", "creature", "blue", "instant"],
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
            ["red", "blue"],
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
            ["red", "blue", "instant"],
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
        
        // Nested parentheses
        TestCase(
            "((red or blue) creature)",
            ["red", "blue", "creature"],
            disj(
                conj(
                    .disjunction(
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
                            ),
                        ),
                    ),
                ),
            ),
            "(red or blue) creature",
        ),
        
        // Multiple parenthesized groups
        TestCase(
            "(red or blue) or (black or white)",
            ["red", "blue", "black", "white"],
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
            ["red", "blue", "creature", "flying", "haste"],
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
            ["\"lightning bolt\"", "\"chain lightning\""],
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
            ["red", "blue"],
        ),
        
        // Unmatched closing parenthesis
        TestCase(
            "red or blue)",
            ["red", "blue"],
        ),
        
        // OR at end - gets ignored
        TestCase(
            "red or",
            ["red"],
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
        TestCase(
            "-red -blue",
            ["-red", "-blue"],
            disj(
                conj(
                    .filter("-red"),
                    .filter("-blue"),
                ),
            ),
            "-red -blue",
        ),
        
        // Negation with OR and AND
        TestCase(
            "-red or blue",
            ["-red", "blue"],
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
        TestCase(
            "-red creature",
            ["-red", "creature"],
            disj(
                conj(
                    .filter("-red"),
                    .filter("creature"),
                ),
            ),
            "-red creature",
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
            ["-red", "-blue"],
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
        TestCase(
            "name:bolt color:red",
            ["name:bolt", "color:red"],
            disj(
                conj(
                    .filter("name:bolt"),
                    .filter("color:red"),
                ),
            ),
            "name:bolt color:red",
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
        TestCase(
            "cmc>=4",
            ["cmc>=4"],
            disj(
                conj(
                    .filter("cmc>=4"),
                ),
            ),
            "cmc>=4",
        ),
        TestCase(
            "power<3",
            ["power<3"],
            disj(
                conj(
                    .filter("power<3"),
                ),
            ),
            "power<3",
        ),
        TestCase(
            "type!=instant",
            ["type!=instant"],
            disj(
                conj(
                    .filter("type!=instant"),
                ),
            ),
            "type!=instant",
        ),
        
        // Mixed with OR and parentheses
        TestCase(
            "name:lightning or name:bolt",
            ["name:lightning", "name:bolt"],
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
            ["power>=2", "toughness>=3"],
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
            "creature power>=3",
            ["creature", "power>=3"],
            disj(
                conj(
                    .filter("creature"),
                    .filter("power>=3"),
                ),
            ),
            "creature power>=3",
        ),
        TestCase(
            "((name:lightning) or (name:bolt))",
            ["name:lightning", "name:bolt"],
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
        TestCase(
            "name:\"lightning bolt\" type:\"instant\"",
            ["name:\"lightning bolt\"", "type:\"instant\""],
            disj(
                conj(
                    .filter("name:\"lightning bolt\""),
                    .filter("type:\"instant\""),
                ),
            ),
            "name:\"lightning bolt\" type:\"instant\"",
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
            "name:\"Serra Angel\" oracle:'draw a card'",
            ["name:\"Serra Angel\"", "oracle:'draw a card'"],
            disj(
                conj(
                    .filter("name:\"Serra Angel\""),
                    .filter("oracle:'draw a card'"),
                ),
            ),
            "name:\"Serra Angel\" oracle:'draw a card'",
        ),
        TestCase(
            "(name:\"Serra Angel\" or name:\"Akroma\")",
            ["name:\"Serra Angel\"", "name:\"Akroma\""],
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
            "power> creature",
            ["power>", "creature"],
            disj(
                conj(
                    .filter("power>"),
                    .filter("creature"),
                ),
            ),
            "power> creature",
        ),
        TestCase(
            "(power>) or (name:)",
            ["power>", "name:"],
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
            "name:\"lightning",
            ["name:\"lightning"],
        ),
        TestCase(
            "name:\"lightning bolt",
            ["name:\"lightning bolt"],
        ),
        
        // Unclosed single quotes
        TestCase(
            "name:'lightning",
            ["name:'lightning"],
        ),
        TestCase(
            "oracle:'draw a card",
            ["oracle:'draw a card"],
        ),
        
        // Unclosed quotes in parentheses - closing paren becomes part of the string
        TestCase(
            "(name:\"lightning)",
            ["name:\"lightning)"],
        ),
        TestCase(
            "(oracle:'deals damage)",
            ["oracle:'deals damage)"],
        ),
        
        // MARK: Incomplete Regex Patterns
        
        // Unclosed regex - these consume everything including whitespace
        TestCase(
            "/^light",
            ["/^light"],
        ),
        TestCase(
            "/^light creature",
            ["/^light creature"],
        ),
        TestCase(
            "/.+ name:test",
            ["/.+ name:test"],
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
        
        // Unclosed regex in parentheses
        TestCase(
            "(/^light)",
            ["/^light)"],
        ),
        
        // Unclosed regex with OR in the middle
        TestCase(
            "/^light or /bolt",
            ["/^light or /bolt"],
            disj(
                conj(
                    .filter("/^light or /bolt"),
                ),
            ),
            "/^light or /bolt",
        ),
        
        // MARK: Nested and Incomplete Parentheses
        
        // Unclosed single level
        TestCase(
            "(red",
            ["red"],
        ),
        TestCase(
            "(red or blue",
            ["red", "blue"],
        ),
        
        // Unclosed nested
        TestCase(
            "((red)",
            ["red"],
        ),
        TestCase(
            "(((red or blue) creature",
            ["red", "blue", "creature"],
        ),
        
        // Extra closing parentheses
        TestCase(
            "red)",
            ["red"],
        ),
        TestCase(
            "(red))",
            ["red"],
        ),
        
        // Empty unclosed parentheses
        TestCase(
            "(",
            [],
        ),
        TestCase(
            "red (",
            ["red"],
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
            "-color:red creature",
            ["-color:red", "creature"],
            disj(
                conj(
                    .filter("-color:red"),
                    .filter("creature"),
                ),
            ),
            "-color:red creature",
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
        TestCase(
            "creature -cmc>=4",
            ["creature", "-cmc>=4"],
            disj(
                conj(
                    .filter("creature"),
                    .filter("-cmc>=4"),
                ),
            ),
            "creature -cmc>=4",
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
        TestCase(
            "-oracle:'draw a card'",
            ["-oracle:'draw a card'"],
            disj(
                conj(
                    .filter("-oracle:'draw a card'"),
                ),
            ),
            "-oracle:'draw a card'",
        ),
        
        // Incomplete terms with negation
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
        TestCase(
            "-name:\"lightning",
            ["-name:\"lightning"],
        ),
        
        // Nested parentheses with multiple features
        TestCase(
            "((name:lightning or -name:bolt) power>3)",
            ["name:lightning", "-name:bolt", "power>3"],
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
            ["red"],
        ),
        TestCase(
            "red or or blue",
            ["red", "blue"],
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
