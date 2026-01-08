import SwiftUI
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
    func testRemoveAutoinsertedWhitespace(input: String, expected: String) {
        let result = removeAutoinsertedWhitespace(input, input.endIndexRange)
        #expect(result?.0 == expected)
    }

    @Test("Selection adjustment cases", arguments: [
        // Selection at the start
        ("color: red", 0..<0, "color:red", 0..<0),
        
        // Selection before the space
        ("color: red", 5..<5, "color:red", 5..<5),
        
        // Selection after the space
        ("color: red", 7..<7, "color:red", 6..<6),
        
        // Selection in the middle of value
        ("color: red", 9..<9, "color:red", 8..<8),
        
        // Selection at the end
        ("color: red", 10..<10, "color:red", 9..<9),
        
        // Selection range across the space
        ("color: red", 5..<7, "color:red", 5..<6),
        
        // Selection range after the space
        ("color: red", 7..<10, "color:red", 6..<9),
        
        // Multiple filters - selection in second filter
        ("color: red type: instant", 19..<19, "color:red type:instant", 17..<17),
        
        // No whitespace to remove - selection unchanged
        ("color:red", 5..<5, "color:red", 5..<5),
        
        // Range selection spanning multiple filters
        ("color: red type: instant", 5..<19, "color:red type:instant", 5..<17),
    ])
    func testSelectionAdjustment(
        input: String,
        selection: Range<Int>,
        expected: String,
        expectedSelection: Range<Int>,
    ) throws {
        let actual = removeAutoinsertedWhitespace(input, selection.toStringIndices(in: input)!)
        try #require(actual != nil)
        #expect(actual!.0 == expected)
        #expect(actual!.1 == expectedSelection.toStringIndices(in: actual!.0)!)
    }
}
