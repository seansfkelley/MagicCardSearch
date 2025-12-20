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
    // MARK: - Simple Queries
    
    @Test("Parse single verbatim term")
    func singleTerm() throws {
        let input = "lightning"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 1)
        #expect(String(input[result.filters[0]]) == "lightning")
    }
    
    @Test("Parse quoted string")
    func quotedString() throws {
        let input = "\"lightning bolt\""
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 1)
        #expect(String(input[result.filters[0]]) == "\"lightning bolt\"")
    }
    
    @Test("Parse regex pattern")
    func regexPattern() throws {
        let input = "/^light/"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 1)
        #expect(String(input[result.filters[0]]) == "/^light/")
    }
    
    @Test("Parse single quoted string")
    func singleQuotedString() throws {
        let input = "'Serra Angel'"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 1)
        #expect(String(input[result.filters[0]]) == "'Serra Angel'")
    }
    
    // MARK: - AND Queries (Implicit with Whitespace)
    
    @Test("Parse two terms with AND")
    func twoTermsAnd() throws {
        let input = "lightning bolt"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        #expect(String(input[result.filters[0]]) == "lightning")
        #expect(String(input[result.filters[1]]) == "bolt")
    }
    
    @Test("Parse multiple terms with AND")
    func multipleTermsAnd() throws {
        let input = "red creature haste"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 3)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "creature")
        #expect(String(input[result.filters[2]]) == "haste")
    }
    
    @Test("Parse terms with extra whitespace")
    func termsWithExtraWhitespace() throws {
        let input = "  lightning   bolt  "
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        #expect(String(input[result.filters[0]]) == "lightning")
        #expect(String(input[result.filters[1]]) == "bolt")
    }
    
    // MARK: - OR Queries
    
    @Test("Parse two terms with OR")
    func twoTermsOr() throws {
        let input = "lightning or bolt"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        #expect(String(input[result.filters[0]]) == "lightning")
        #expect(String(input[result.filters[1]]) == "bolt")
    }
    
    @Test("Parse multiple terms with OR")
    func multipleTermsOr() throws {
        let input = "red or blue or green"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 3)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
        #expect(String(input[result.filters[2]]) == "green")
    }
    
    // MARK: - Mixed AND/OR Queries
    
    @Test("Parse AND with OR - precedence test")
    func andOrPrecedence() throws {
        let input = "red creature or blue instant"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 4)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "creature")
        #expect(String(input[result.filters[2]]) == "blue")
        #expect(String(input[result.filters[3]]) == "instant")
    }
    
    // MARK: - Parenthesized Queries
    
    @Test("Parse simple parenthesized query")
    func simpleParenthesized() throws {
        let input = "(lightning)"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 1)
        #expect(String(input[result.filters[0]]) == "lightning")
    }
    
    @Test("Parse parenthesized OR query")
    func parenthesizedOr() throws {
        let input = "(red or blue)"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
    }
    
    @Test("Parse parentheses changing precedence")
    func parenthesesChangePrecedence() throws {
        let input = "(red or blue) instant"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 3)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
        #expect(String(input[result.filters[2]]) == "instant")
    }
    
    @Test("Parse nested parentheses")
    func nestedParentheses() throws {
        let input = "((red or blue) creature)"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 3)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
        #expect(String(input[result.filters[2]]) == "creature")
    }
    
    @Test("Parse multiple parenthesized groups")
    func multipleParenthesizedGroups() throws {
        let input = "(red or blue) or (black or white)"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 4)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
        #expect(String(input[result.filters[2]]) == "black")
        #expect(String(input[result.filters[3]]) == "white")
    }
    
    // MARK: - Complex Queries
    
    @Test("Parse complex mixed query")
    func complexMixedQuery() throws {
        let input = "(red or blue) creature (flying or haste)"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 5)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
        #expect(String(input[result.filters[2]]) == "creature")
        #expect(String(input[result.filters[3]]) == "flying")
        #expect(String(input[result.filters[4]]) == "haste")
    }
    
    @Test("Parse query with quoted strings in parentheses")
    func quotedStringsInParentheses() throws {
        let input = "(\"lightning bolt\" or \"chain lightning\")"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        #expect(String(input[result.filters[0]]) == "\"lightning bolt\"")
        #expect(String(input[result.filters[1]]) == "\"chain lightning\"")
    }
    
    // MARK: - Edge Cases
    
    @Test("Parse empty parentheses")
    func emptyParentheses() throws {
        let input = "()"
        let result = try ParenthesizedQuery.tryParse(input)
        
        #expect(result.filters.isEmpty)
    }
    
    @Test("Parse unclosed parenthesis")
    func unclosedParenthesis() throws {
        let input = "(red or blue"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
    }
    
    @Test("Parse unmatched closing parenthesis")
    func unmatchedClosingParenthesis() throws {
        let input = "red or blue)"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
    }
    
    @Test("Parse whitespace only")
    func whitespaceOnly() throws {
        let input = "   "
        let result = try ParenthesizedQuery.tryParse(input)
        
        #expect(result.filters.isEmpty)
    }
    
    @Test("Parse OR at beginning")
    func orAtBeginning() throws {
        let input = "or red"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 1)
        #expect(String(input[result.filters[0]]) == "red")
    }
    
    @Test("Parse OR at end")
    func orAtEnd() throws {
        let input = "red or"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 1)
        #expect(String(input[result.filters[0]]) == "red")
    }
    
    @Test("Parse consecutive ORs")
    func consecutiveOrs() throws {
        let input = "red or or blue"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        #expect(String(input[result.filters[0]]) == "red")
        #expect(String(input[result.filters[1]]) == "blue")
    }
    
    // MARK: - Range Verification
    
    @Test("Verify filter ranges are correct")
    func filterRangesAreCorrect() throws {
        let input = "lightning bolt"
        let result = try ParenthesizedQuery.tryParse(input)
        
        try #require(result.filters.count == 2)
        
        let firstFilter = String(input[result.filters[0]])
        let secondFilter = String(input[result.filters[1]])
        
        #expect(firstFilter == "lightning")
        #expect(secondFilter == "bolt")
    }
}
