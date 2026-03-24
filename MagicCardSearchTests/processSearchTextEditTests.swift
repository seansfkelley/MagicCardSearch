import SwiftUI
import Testing
@testable import MagicCardSearch

@Suite("processSearchTextEdit")
struct ProcessSearchTextEditTests {
    // Each case is (textBefore, inserted, insertionRange) where insertionRange is in textBefore.
    @Test<[(String, String, Range<Int>)]>("returns nil", arguments: [
        // Appending a second space to whitespace-only string
        ("\"lightning ", " ", 11..<11),
        // Appending space after incomplete parenthesized expression
        ("(color:red", " ", 10..<10),
        // Appending space after bare filter keyword with no value
        ("color:", " ", 6..<6),
        // Multi-char paste that doesn't match a single-keystroke path
        ("colorred", "color:red", 0..<8),
        // Deletion (empty insertion)
        ("color:red", "", 8..<9),
        // Multi-char insertion that isn't a recognized completion
        ("color", ":red", 5..<5),
        // Appending apostrophe to a bare word
        ("lightning", "'", 9..<9),
        // Appending space inside an unterminated single-quote
        ("'lightning", " ", 10..<10),
        // Appending space inside an unterminated double-quote
        ("\"lightning", " ", 10..<10),
        // Appending a char in the middle of a balanced quoted string
        ("\"urza's sag\"", "a", 11..<11),
        // Appending ) or / to an empty string doesn't complete a filter
        ("", ")", 0..<0),
        ("", "/", 0..<0),
    ])
    func returnsNil(textBefore: String, inserted: String, insertionRange: Range<Int>) {
        let range = insertionRange.toStringIndices(in: textBefore)!
        #expect(processSearchTextEdit(textBefore, inserting: inserted, inRange: range) == nil)
    }

    // swiftlint:disable:next large_tuple
    @Test<[(String, String, Range<Int>, (FilterQuery<FilterTerm>?, String, Range<Int>?))]>(
        "returns non-nil",
        arguments: [
            // Inserting into an empty string produces an empty result
            ("", "", 0..<0, (nil, "", nil)),
            // Appending space to whitespace-only text clears the field
            (" ", " ", 1..<1, (nil, "", nil)),
            // Appending space to a bare word starts a quoted name
            ("lightning", " ", 9..<9, (nil, "\"lightning ", nil)),
            // Same with a negated bare word
            ("-lightning", " ", 10..<10, (nil, "-\"lightning ", nil)),
            // Bare word with apostrophe gets double-quote wrapping
            ("urza's", " ", 6..<6, (nil, "\"urza's ", nil)),
            // Closing double-quote completes a name filter
            (
                "\"urza's saga",
                "\"",
                12..<12,
                (.term(.name(.positive, false, "urza's saga")), "", nil),
            ),
            // Closing slash completes a regex filter
            (
                "oracle:/bolt",
                "/",
                12..<12,
                (.term(.regex(.positive, "oracle", .including, "bolt")), "", nil),
            ),
            // Pasting " red" after "color:" elides the space; selection tracks the pasted range
            ("color:", " red", 6..<6, (nil, "color:red", 6..<9)),
            // Closing paren completes an or-expression
            (
                "(color:red or color:blue",
                ")",
                24..<24,
                (
                    .or(
                        .positive,
                        [
                            .term(.basic(.positive, "color", .including, "red")),
                            .term(.basic(.positive, "color", .including, "blue")),
                        ],
                    ),
                    "",
                    nil,
                ),
            ),
        ],
    )
    func returnsNonNil(
        textBefore: String,
        inserted: String,
        insertionRange: Range<Int>,
        expected: (FilterQuery<FilterTerm>?, String, Range<Int>?)
    ) throws {
        let range = insertionRange.toStringIndices(in: textBefore)!
        let result = try #require(processSearchTextEdit(textBefore, inserting: inserted, inRange: range))
        #expect(result == (
            expected.0,
            expected.1,
            expected.2.map { $0.toStringIndices(in: result.1)! },
        ))
    }
}

@Suite("elideExtraneousWhitespace")
struct ElideExtraneousWhitespaceTests {
    // Each case is (prefix, edit, expectedText) where prefix is existing text, edit is what's
    // inserted (must start with whitespace and end with non-whitespace), and expectedText is the
    // result after eliding the extraneous leading space.
    @Test("removes extraneous whitespace between filter and value", arguments: [
        // Basic operator cases
        ("color:", " red", "color:red"),
        ("power=", " 5", "power=5"),
        ("rarity!=", " common", "rarity!=common"),
        ("cmc<", " 3", "cmc<3"),
        ("power>", " 4", "power>4"),
        ("toughness<=", " 2", "toughness<=2"),
        ("loyalty>=", " 5", "loyalty>=5"),

        // Negated filter
        ("-color:", " blue", "-color:blue"),

        // Multiple filters: elide the space before the second value only
        ("color:red rarity:", " rare", "color:red rarity:rare"),

        // Multiple incomplete filters: only the complete filter's space is elided
        ("color: name:", " lightning", "color: name:lightning"),

        // Parenthesized expression: both filter-adjacent spaces are elided
        ("(color:", " red or color: blue)", "(color:red or color:blue)"),
    ])
    func removesWhitespace(prefix: String, edit: String, expected: String) {
        let input = prefix + edit
        let editStart = input.index(input.startIndex, offsetBy: prefix.count)
        let result = elideExtraneousWhitespace(in: input, withLastEditAt: editStart..<input.endIndex)
        #expect(result?.newText == expected)
    }

    @Test("returns nil when no extraneous whitespace to remove", arguments: [
        // Quoted strings (spaces are inside quotes, not between filter and value)
        "name:\"Serra Angel\"",
        "name:'Lightning Bolt'",
        "oracle:/foo bar/",

        // Already no extraneous whitespace
        "color:red rarity:rare",
        "color:red",

        // Unterminated quoted string
        "name:\"Serra",

        // Comparison spacing is on the wrong side (name, not filter value)
        "color <= izzet",
        "color <=izzet",
    ])
    func returnsNil(input: String) {
        let result = elideExtraneousWhitespace(in: input, withLastEditAt: input.startIndex..<input.endIndex)
        #expect(result == nil || result?.newText == input)
    }

    // Each case: (prefix, edit, editSelStart, editSelEnd, expectedText, expectedSelStart, expectedSelEnd)
    // editSel is a range within the edit substring (0-based from start of edit).
    // expectedSel is a range within expectedText (0-based).
    // editSelStart/editSelEnd are offsets from the start of `edit` within the full input string.
    // expectedSelStart/expectedSelEnd are absolute offsets from the start of `expectedText`.
    @Test("tracks selection range through elision", arguments: [
        // Full " red" edit: lower at and-token start stays put, upper shifts back 1 for the removed space
        ("color:", " red", 0, 4, "color:red", 6, 9),

        // Selection covers only " r": upper shifts back 1
        ("color:", " red", 0, 2, "color:red", 6, 7),

        // Selection covers only " re": upper shifts back 1
        ("color:", " red", 0, 3, "color:red", 6, 8),

        // Multi-filter: full " rare" edit after "color:red rarity:"
        ("color:red rarity:", " rare", 0, 5, "color:red rarity:rare", 17, 21),

        // Multi-filter: selection covers only " ra"
        ("color:red rarity:", " rare", 0, 3, "color:red rarity:rare", 17, 19),
    ])
    func tracksSelection(
        prefix: String,
        edit: String,
        editSelStart: Int,
        editSelEnd: Int,
        expectedText: String,
        expectedSelStart: Int,
        expectedSelEnd: Int,
    ) throws {
        let input = prefix + edit
        let editStart = input.index(input.startIndex, offsetBy: prefix.count)
        let lower = input.index(editStart, offsetBy: editSelStart)
        let upper = input.index(editStart, offsetBy: editSelEnd)
        let result = try #require(elideExtraneousWhitespace(in: input, withLastEditAt: lower..<upper))
        #expect(result.newText == expectedText)
        let expectedRange = (expectedSelStart..<expectedSelEnd).toStringIndices(in: result.newText)
        #expect(result.newSelection == expectedRange)
    }
}
