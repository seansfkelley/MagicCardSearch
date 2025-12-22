//
//  ParenthesizedQueryTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//

import Testing
@testable import MagicCardSearch

// Serialized: Citron is not thread-safe.
@Suite(.serialized)
struct ParenthesizedQueryTests {
    // MARK: - Comprehensive Query Parsing Tests
    
    @Test("Parse all query types", arguments: [
        // MARK: Simple Queries
        
        // Single terms
        (
            "lightning",
            ["lightning"],
        ),
        
        // Quoted strings
        (
            "\"lightning bolt\"",
            ["\"lightning bolt\""],
        ),
        (
            "'Serra Angel'",
            ["'Serra Angel'"],
        ),
        
        // Regex patterns
        (
            "/^light/",
            ["/^light/"],
        ),
        
        // MARK: AND Queries (Implicit with Whitespace)
        
        // Two terms
        (
            "lightning bolt",
            ["lightning", "bolt"],
        ),
        
        // Multiple terms
        (
            "red creature haste",
            ["red", "creature", "haste"],
        ),
        
        // Extra whitespace gets trimmed by lexer
        (
            "  lightning   bolt  ",
            ["lightning", "bolt"],
        ),
        
        // MARK: OR Queries
        
        // Two terms
        (
            "lightning or bolt",
            ["lightning", "bolt"],
        ),
        
        // Multiple terms
        (
            "red or blue or green",
            ["red", "blue", "green"],
        ),
        
        // AND with OR - precedence test
        (
            "red creature or blue instant",
            ["red", "creature", "blue", "instant"],
        ),
        
        // MARK: Parenthesized Queries
        
        // Simple parenthesized
        (
            "(lightning)",
            ["lightning"],
        ),
        
        // Parenthesized OR
        (
            "(red or blue)",
            ["red", "blue"],
        ),
        
        // Parentheses changing precedence
        (
            "(red or blue) instant",
            ["red", "blue", "instant"],
        ),
        
        // Nested parentheses
        (
            "((red or blue) creature)",
            ["red", "blue", "creature"],
        ),
        
        // Multiple parenthesized groups
        (
            "(red or blue) or (black or white)",
            ["red", "blue", "black", "white"],
        ),
        
        // Complex mixed query
        (
            "(red or blue) creature (flying or haste)",
            ["red", "blue", "creature", "flying", "haste"],
        ),
        
        // Quoted strings in parentheses
        (
            "(\"lightning bolt\" or \"chain lightning\")",
            ["\"lightning bolt\"", "\"chain lightning\""],
        ),
        
        // MARK: Edge Cases
        
        // Empty and whitespace
        (
            "()",
            [],
        ),

        // Unclosed parentheses
        (
            "(red or blue",
            ["red", "blue"],
        ),
        
        // Unmatched closing parenthesis
        (
            "red or blue)",
            ["red", "blue"],
        ),
        
        // OR at end - gets ignored
        (
            "red or",
            ["red"],
        ),
        
        // MARK: Negation
        
        // Simple negation
        (
            "-lightning",
            ["-lightning"],
        ),
        (
            "-red -blue",
            ["-red", "-blue"],
        ),
        
        // Negation with OR and AND
        (
            "-red or blue",
            ["-red", "blue"],
        ),
        (
            "-red creature",
            ["-red", "creature"],
        ),
        
        // Negation in parentheses
        (
            "(-red)",
            ["-red"],
        ),
        (
            "(-red or -blue)",
            ["-red", "-blue"],
        ),
        
        // MARK: Key:Value and Comparison Operators
        
        // Simple key:value
        (
            "name:lightning",
            ["name:lightning"],
        ),
        (
            "name:bolt color:red",
            ["name:bolt", "color:red"],
        ),
        
        // Comparison operators (representative samples)
        (
            "power>3",
            ["power>3"],
        ),
        (
            "cmc>=4",
            ["cmc>=4"],
        ),
        (
            "power<3",
            ["power<3"],
        ),
        (
            "type!=instant",
            ["type!=instant"],
        ),
        
        // Mixed with OR and parentheses
        (
            "name:lightning or name:bolt",
            ["name:lightning", "name:bolt"],
        ),
        (
            "(power>=2 or toughness>=3)",
            ["power>=2", "toughness>=3"],
        ),
        
        // Mixed with regular terms
        (
            "creature power>=3",
            ["creature", "power>=3"],
        ),
        (
            "((name:lightning) or (name:bolt))",
            ["name:lightning", "name:bolt"],
        ),
        
        // MARK: Quoted Values
        
        // Double quotes
        (
            "name:\"lightning bolt\"",
            ["name:\"lightning bolt\""],
        ),
        (
            "name:\"lightning bolt\" type:\"instant\"",
            ["name:\"lightning bolt\"", "type:\"instant\""],
        ),
        
        // Single quotes
        (
            "name:'lightning bolt'",
            ["name:'lightning bolt'"],
        ),
        
        // Mixed quotes with OR and parentheses
        (
            "name:\"Serra Angel\" oracle:'draw a card'",
            ["name:\"Serra Angel\"", "oracle:'draw a card'"],
        ),
        (
            "(name:\"Serra Angel\" or name:\"Akroma\")",
            ["name:\"Serra Angel\"", "name:\"Akroma\""],
        ),
        
        // MARK: Incomplete Terms and Quoted Strings
        
        // Incomplete operators and key:value
        (
            "power>",
            ["power>"],
        ),
        (
            "name:",
            ["name:"],
        ),
        (
            "power> creature",
            ["power>", "creature"],
        ),
        (
            "(power>) or (name:)",
            ["power>", "name:"],
        ),
        
        // Unclosed double quotes - these consume everything after including whitespace
        (
            "name:\"lightning",
            ["name:\"lightning"],
        ),
        (
            "name:\"lightning bolt",
            ["name:\"lightning bolt"],
        ),
        
        // Unclosed single quotes
        (
            "name:'lightning",
            ["name:'lightning"],
        ),
        (
            "oracle:'draw a card",
            ["oracle:'draw a card"],
        ),
        
        // Unclosed quotes in parentheses - closing paren becomes part of the string
        (
            "(name:\"lightning)",
            ["name:\"lightning)"],
        ),
        (
            "(oracle:'deals damage)",
            ["oracle:'deals damage)"],
        ),
        
        // MARK: Incomplete Regex Patterns
        
        // Unclosed regex - these consume everything including whitespace
        (
            "/^light",
            ["/^light"],
        ),
        (
            "/^light creature",
            ["/^light creature"],
        ),
        (
            "/.+ name:test",
            ["/.+ name:test"],
        ),
        
        // Multiple unclosed regex
        (
            "/^light /end$",
            ["/^light /end$"],
        ),
        
        // Unclosed regex in parentheses
        (
            "(/^light)",
            ["/^light)"],
        ),
        
        // Unclosed regex with OR in the middle
        (
            "/^light or /bolt",
            ["/^light or /bolt"],
        ),
        
        // MARK: Nested and Incomplete Parentheses
        
        // Unclosed single level
        (
            "(red",
            ["red"],
        ),
        (
            "(red or blue",
            ["red", "blue"],
        ),
        
        // Unclosed nested
        (
            "((red)",
            ["red"],
        ),
        (
            "(((red or blue) creature",
            ["red", "blue", "creature"],
        ),
        
        // Extra closing parentheses
        (
            "red)",
            ["red"],
        ),
        (
            "(red))",
            ["red"],
        ),
        
        // Empty unclosed parentheses
        (
            "(",
            [],
        ),
        (
            "red (",
            ["red"],
        ),
        
        // MARK: Complex Combinations
        
        // Negation with key:value and comparisons
        (
            "-name:lightning",
            ["-name:lightning"],
        ),
        (
            "-color:red creature",
            ["-color:red", "creature"],
        ),
        (
            "-power>3",
            ["-power>3"],
        ),
        (
            "creature -cmc>=4",
            ["creature", "-cmc>=4"],
        ),
        
        // Negation with quoted values (various quote types)
        (
            "-name:\"lightning bolt\"",
            ["-name:\"lightning bolt\""],
        ),
        (
            "-oracle:'draw a card'",
            ["-oracle:'draw a card'"],
        ),
        
        // Incomplete terms with negation
        (
            "-power>",
            ["-power>"],
        ),
        (
            "-name:\"lightning",
            ["-name:\"lightning"],
        ),
        
        // Nested parentheses with multiple features
        (
            "((name:lightning or -name:bolt) power>3)",
            ["name:lightning", "-name:bolt", "power>3"],
        ),
        
        // Incomplete nested with mixed quotes and operators
        (
            "((name:\"lightning power>3",
            ["name:\"lightning power>3"],
        ),
        (
            "name:'bolt type:creature",
            ["name:'bolt type:creature"],
        ),
    ])
    func parseAllQueryTypes(input: String, expected: [String]) throws {
        let result = try PlausibleFilterRanges.from(input)
        let actual = result.ranges.map { String(input[$0]) }
        #expect(actual == expected)
    }
    
    @Test("not-yet-handled cases", arguments: [
        // Whitespace-only input throws instead of returning empty
        (
            "   ",
            [],
        ),
        // OR at beginning - should be ignored but currently returns empty
        (
            "or red",
            ["red"],
        ),
        // Consecutive ORs - should ignore extra OR but only returns first term
        (
            "red or or blue",
            ["red", "blue"],
        ),
    ])
    func unhandledCases(input: String, expected: [String]) throws {
        withKnownIssue {
            let result = try PlausibleFilterRanges.from(input)
            let actual = result.ranges.map { String(input[$0]) }
            #expect(actual == expected)
        }
    }
}
