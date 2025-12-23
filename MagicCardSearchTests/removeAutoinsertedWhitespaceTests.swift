//
//  removeAutoinsertedWhitespaceTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-23.
//
import Testing
@testable import MagicCardSearch

@Suite("Remove Autoinserted Whitespace")
struct RemoveAutoinsertedWhitespaceTests {
    @Test(arguments: [
        // Basic operator cases
        ("color: red", "color:red"),
        ("power= 5", "power=5"),
        ("rarity!= common", "rarity!=common"),
        ("cmc< 3", "cmc<3"),
        ("power> 4", "power>4"),
        ("toughness<= 2", "toughness<=2"),
        ("loyalty>= 5", "loyalty>=5"),
        
        // Multiple filters
        ("color: red rarity: rare", "color:red rarity:rare"),
        
        // Negated filters
        ("-color: blue", "-color:blue"),
        
        // Parenthesized expressions
        ("(color: red or color: blue)", "(color:red or color:blue)"),
        ("(color: red rarity: rare) or (color: blue power: 3)", "(color:red rarity:rare) or (color:blue power:3)"),
        
        // Quoted strings (should be preserved)
        ("name:\"Serra Angel\"", "name:\"Serra Angel\""),
        ("name:'Lightning Bolt'", "name:'Lightning Bolt'"),
        ("oracle:/foo bar/", "oracle:/foo bar/"),
        
        // Already correct (no changes needed)
        ("color:red rarity:rare", "color:red rarity:rare"),
        ("color:red", "color:red"),

        // Unterminated quoted strings
        ("name:\"Serra", "name:\"Serra"),
        
        // Empty filter values
        ("color: ", "color: "),

        // Multiple incomplete filters should not telescope
        ("color: name: lightning", "color: name:lightning"),

        // Comparison spacing in the wrong place makes no changes
        ("color <= izzet", "color <= izzet"),
        ("color <=izzet", "color <=izzet"),
    ])
    func testRemoveAutoinsertedWhitespace(input: String, expected: String?) {
        let result = removeAutoinsertedWhitespace(input)
        #expect(result == expected)
    }
}
