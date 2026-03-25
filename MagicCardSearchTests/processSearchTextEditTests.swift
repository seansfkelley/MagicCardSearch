import SwiftUI
import Testing
@testable import MagicCardSearch

typealias IntSearchTextEdit = (filter: FilterQuery<FilterTerm>?, newText: String, newSelection: Range<Int>?)

@Suite("processSearchTextEdit")
struct ProcessSearchTextEditTests {
    @Test<[(String, String, Range<Int>)]>("returns nil", arguments: [
        // Multi-char paste that doesn't match any helper's criteria
        ("colorred", "color:red", 0..<8),
        // Deletion
        ("color:red", "", 8..<9),
        // Multi-char insertion that isn't a recognized completion
        ("color", ":red", 5..<5),
    ])
    func returnsNil(textBefore: String, inserted: String, insertionRange: Range<Int>) {
        let range = insertionRange.toStringIndices(in: textBefore)!
        #expect(processSearchTextEdit(textBefore, inserting: inserted, inRange: range) == nil)
    }

    // swiftlint:disable:next large_tuple
    @Test<[(String, String, Range<Int>, IntSearchTextEdit)]>(
        "returns non-nil",
        arguments: [
            // Early return: empty candidate
            ("", "", 0..<0, (nil, "", nil)),
            // Early return: all-whitespace candidate
            (" ", " ", 1..<1, (nil, "", nil)),
            // Single-char path via inferIntentFromAppendingOneCharacter
            ("lightning", " ", 9..<9, (nil, "\"lightning ", nil)),
            // Multi-char path via elideExtraneousWhitespace
            ("color:", " red", 6..<6, (nil, "color:red", 6..<9)),
            // Multi-char path via quoteAdjacentBareWords
            ("lightning", " bolt", 9..<9, (nil, "\"lightning bolt\"", 15..<15)),
        ],
    )
    func returnsNonNil(
        textBefore: String,
        inserted: String,
        insertionRange: Range<Int>,
        expected: IntSearchTextEdit,
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

@Suite("inferIntentFromAppendingOneCharacter")
struct InferIntentFromAppendingOneCharacterTests {
    @Test<[(String, String, Range<Int>)]>("returns nil", arguments: [
        // Not a single char at end
        ("\"lightning ", " ", 11..<11),
        // Space after incomplete parenthesized expression
        ("(color:red", " ", 10..<10),
        // Space after bare filter keyword with no value
        ("color:", " ", 6..<6),
        // Apostrophe appended to a bare word (uninitiated quote, not a valid filter)
        ("lightning", "'", 9..<9),
        // Space inside an unterminated single-quote
        ("'lightning", " ", 10..<10),
        // Space inside an unterminated double-quote
        ("\"lightning", " ", 10..<10),
        // ) or / appended to an empty string
        ("", ")", 0..<0),
        ("", "/", 0..<0),
    ])
    func returnsNil(textBefore: String, inserted: String, insertionRange: Range<Int>) {
        let candidate = textBefore.replacingCharacters(
            in: insertionRange.toStringIndices(in: textBefore)!,
            with: inserted,
        )
        let editedRange = candidate.index(candidate.endIndex, offsetBy: -1)..<candidate.endIndex
        #expect(inferIntentFromAppendingOneCharacter(in: candidate, withLastEditAt: editedRange) == nil)
    }

    // swiftlint:disable:next large_tuple
    @Test<[(String, String, Range<Int>, IntSearchTextEdit)]>(
        "returns non-nil",
        arguments: [
            // Space appended to a bare word starts a quoted name
            ("lightning", " ", 9..<9, (nil, "\"lightning ", nil)),
            // Same with a negated bare word
            ("-lightning", " ", 10..<10, (nil, "-\"lightning ", nil)),
            // Bare word with uninitiated apostrophe gets double-quote wrapping
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
        expected: IntSearchTextEdit,
    ) throws {
        let candidate = textBefore.replacingCharacters(
            in: insertionRange.toStringIndices(in: textBefore)!,
            with: inserted,
        )
        let editedRange = candidate.index(candidate.endIndex, offsetBy: -1)..<candidate.endIndex
        let result = try #require(inferIntentFromAppendingOneCharacter(in: candidate, withLastEditAt: editedRange))
        #expect(result == (
            expected.0,
            expected.1,
            expected.2.map { $0.toStringIndices(in: result.1)! },
        ))
    }
}

@Suite("elideExtraneousWhitespace")
struct ElideExtraneousWhitespaceTests {
    // Each case is (prefix, edit) where the full input is prefix+edit and the edit range covers
    // the edit portion. The edit must start with whitespace and end with non-whitespace.
    @Test("returns nil", arguments: [
        // Quoted strings (spaces are inside quotes, not between filter and value)
        ("name:", "\"Serra Angel\""),
        ("name:", "'Lightning Bolt'"),
        ("oracle:", "/foo bar/"),

        // Already no extraneous whitespace
        ("color:red ", "rarity:rare"),
        ("color:", "red"),

        // Unterminated quoted string (edit has no leading whitespace)
        ("name:", "\"Serra"),

        // Comparison spacing is on the wrong side (name, not filter value)
        ("color ", "<= izzet"),
        ("color ", "<=izzet"),
    ])
    func returnsNil(prefix: String, edit: String) {
        let input = prefix + edit
        let editStart = input.index(input.startIndex, offsetBy: prefix.count)
        let result = elideExtraneousWhitespace(in: input, withLastEditAt: editStart..<input.endIndex)
        #expect(result == nil || result?.newText == input)
    }

    // editSel is a range of offsets from the start of `edit` (i.e. from prefix.count in the full input).
    // expectedSel is a range of absolute offsets in `expectedText`.
    // swiftlint:disable:next large_tuple
    @Test<[(String, String, Range<Int>, String, Range<Int>)]>("returns non-nil", arguments: [
        // Basic operator cases
        ("color:", " red", 0..<4, "color:red", 6..<9),
        ("power=", " 5", 0..<2, "power=5", 6..<7),
        ("rarity!=", " common", 0..<7, "rarity!=common", 8..<14),
        ("cmc<", " 3", 0..<2, "cmc<3", 4..<5),
        ("power>", " 4", 0..<2, "power>4", 6..<7),
        ("toughness<=", " 2", 0..<2, "toughness<=2", 11..<12),
        ("loyalty>=", " 5", 0..<2, "loyalty>=5", 9..<10),

        // Negated filter
        ("-color:", " blue", 0..<5, "-color:blue", 7..<11),

        // Multiple filters: elide the space before the second value only
        ("color:red rarity:", " rare", 0..<5, "color:red rarity:rare", 17..<21),

        // Multiple incomplete filters: only the complete filter's space is elided
        ("color: name:", " lightning", 0..<10, "color: name:lightning", 12..<21),

        // Parenthesized expression: both filter-adjacent spaces are elided
        ("(color:", " red or color: blue)", 0..<20, "(color:red or color:blue)", 7..<25),

        // Partial selections: upper shifts back for each removed space
        ("color:", " red", 0..<2, "color:red", 6..<7),
        ("color:", " red", 0..<3, "color:red", 6..<8),
        ("color:red rarity:", " rare", 0..<3, "color:red rarity:rare", 17..<19),
    ])
    func returnsNonNil(
        prefix: String,
        edit: String,
        editSel: Range<Int>,
        expectedText: String,
        expectedSel: Range<Int>,
    ) throws {
        let input = prefix + edit
        let editStart = input.index(input.startIndex, offsetBy: prefix.count)
        let lower = input.index(editStart, offsetBy: editSel.lowerBound)
        let upper = input.index(editStart, offsetBy: editSel.upperBound)
        let result = try #require(elideExtraneousWhitespace(in: input, withLastEditAt: lower..<upper))
        #expect(result.newText == expectedText)
        #expect(result.newSelection == expectedSel.toStringIndices(in: result.newText))
    }
}

@Suite("quoteAdjacentBareWords")
struct QuoteAdjacentBareWordsTests {
    @Test("returns nil", arguments: [
        // Only one adjacent bare word — not enough to quote
        ("color:red", " lightning"),
        // Bare word after a completed regex filter — still only one
        ("oracle:/bolt/", " spell"),
        // Single bare word with no predecessor
        ("", " lightning"),
        // Edit doesn't start with whitespace
        ("lightning", "bolt"),
        // Edit ends with whitespace
        ("lightning", " bolt "),
    ])
    func returnsNil(prefix: String, edit: String) {
        let input = prefix + edit
        let editStart = input.index(input.startIndex, offsetBy: prefix.count)
        #expect(quoteAdjacentBareWords(in: input, withLastEditAt: editStart..<input.endIndex) == nil)
    }

    // swiftlint:disable:next large_tuple
    @Test<[(String, String, String, Range<Int>)]>("returns non-nil", arguments: [
        // Two bare words
        ("lightning", " bolt", "\"lightning bolt\"", 15..<15),
        // Three bare words
        ("dark confidant", " soul", "\"dark confidant soul\"", 20..<20),
        // Bare words following a filter
        ("color:red lightning", " bolt", "color:red \"lightning bolt\"", 25..<25),
        // Word with uninitiated apostrophe
        ("urza's", " tower", "\"urza's tower\"", 13..<13),
        // Three words, non-trivial middle word
        ("food goblin", " shaman", "\"food goblin shaman\"", 19..<19),
    ])
    func returnsNonNil(prefix: String, edit: String, expectedText: String, expectedSel: Range<Int>) throws {
        let input = prefix + edit
        let editStart = input.index(input.startIndex, offsetBy: prefix.count)
        let result = try #require(quoteAdjacentBareWords(in: input, withLastEditAt: editStart..<input.endIndex))
        #expect(result.newText == expectedText)
        #expect(result.newSelection == expectedSel.toStringIndices(in: result.newText))
    }
}
