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
    func returnsNil(textBefore: String, inserted: String, insertionRange: Range<Int>) throws {
        let range = try #require(insertionRange.toStringIndices(in: textBefore))
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
            ("lightning", " bolt", 9..<9, (nil, "\"lightning bolt", 15..<15)),
        ],
    )
    func returnsNonNil(
        textBefore: String,
        inserted: String,
        insertionRange: Range<Int>,
        expected: IntSearchTextEdit,
    ) throws {
        let range = try #require(insertionRange.toStringIndices(in: textBefore))
        let result = try #require(processSearchTextEdit(textBefore, inserting: inserted, inRange: range))
        #expect(result.filter == expected.filter)
        #expect(result.newText == expected.newText)
        // n.b. not flatMap on purpose; if we have a non-nil expectation we expect a non-nil conversion.
        let expectedSelection = try expected.newSelection.map { try #require($0.toStringIndices(in: result.newText)) }
        #expect(result.newSelection == expectedSelection)
    }
}

@Suite("inferIntentFromAppendingOneCharacter")
struct InferIntentFromAppendingOneCharacterTests {
    @Test<[(String, Range<Int>)]>("returns nil", arguments: [
        // Character inserted in the middle
        ("color:red", 5..<6),
        // Multi-char paste
        ("\"lightning bolt", 11..<15),
        // Space between first and second terms of a parenthetical
        ("(color:red ", 10..<11),
        // Space after filter -- will wait to start typing filter content
        ("color: ", 6..<7),
        // Apostrophes are not single quotes
        ("lightning'", 9..<10),
        // Unclosed single quote doesn't commit filter
        ("'lightning ", 10..<11),
        // Unclosed double quote doesn't commit filter
        ("\"lightning ", 10..<11),
        // Closing special characters don't... close... the empty string
        (")", 0..<1),
        ("/", 0..<1),
        // TODO: I would like to support the following behavior.
        // Space between an operator and any non-whitespace is not collapsed
        ("type: i", 6..<7),
    ])
    func returnsNil(candidate: String, editedRange: Range<Int>) throws {
        let range = try #require(editedRange.toStringIndices(in: candidate))
        #expect(inferIntentFromAppendingOneCharacter(in: candidate, withLastEditAt: range) == nil)
    }

    @Test<[(String, IntSearchTextEdit)]>(
        "returns non-nil",
        arguments: [
            // Space appended to a bare word starts a quoted name
            (
                "lightning ",
                (nil, "\"lightning ", nil),
            ),
            // Same with a negated bare word
            (
                "-lightning ",
                (nil, "-\"lightning ", nil),
            ),
            // Bare word with apostrophe (not quote) gets double-quote wrapping
            (
                "urza's ",
                (nil, "\"urza's ", nil),
            ),
            // Closing double-quote completes a name filter
            (
                "\"urza's saga\"",
                (.term(.name(.positive, false, "urza's saga")), "", nil),
            ),
            // Closing slash completes a regex filter
            (
                "oracle:/bolt/",
                (.term(.regex(.positive, "oracle", .including, "bolt")), "", nil),
            ),
            // Closing paren completes an or-expression
            (
                "(color:red or color:blue)",
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
    func returnsNonNil(candidate: String, expected: IntSearchTextEdit) throws {
        let range = candidate.index(before: candidate.endIndex)..<candidate.endIndex
        let result = try #require(inferIntentFromAppendingOneCharacter(in: candidate, withLastEditAt: range))
        #expect(result.filter == expected.filter)
        #expect(result.newText == expected.newText)
        // n.b. not flatMap on purpose; if we have a non-nil expectation we expect a non-nil conversion.
        let expectedSelection = try expected.newSelection.map { try #require($0.toStringIndices(in: result.newText)) }
        #expect(result.newSelection == expectedSelection)
    }
}

@Suite("elideExtraneousWhitespace")
struct ElideExtraneousWhitespaceTests {
    @Test("returns nil", arguments: [
        // Quoted strings (spaces are inside quotes, not between filter and value)
        ("name:\"Serra Angel\"", 5..<18, "\"Serra Angel\""),
        ("name:'Serra Angel'", 5..<18, "'Serra Angel'"),
        ("name:/Serra Angel/", 5..<18, "/Serra Angel/"),
        ("name:\"Serra Angel", 11..<17, " Angel"),
        ("name:'Serra Angel", 11..<17, " Angel"),
        ("name:/Serra Angel", 11..<17, " Angel"),

        // No extraneous whitespace on filter
        ("color:red", 6..<9, "red"),

        // Whitespace that isn't part of the edit is not removed
        ("color: red", 7..<10, "red"),

        // Incomplete operators don't allow elision
        ("color! red", 6..<10, " red"),

        // Whitespace separates a term from a complete filter
        ("color:red lightning", 9..<19, " lightning"),
    ])
    func returnsNil(string: String, editRange: Range<Int>, checkString: String) throws {
        let indexRange = try #require(editRange.toStringIndices(in: string))
        try #require(string[indexRange] == checkString)
        #expect(elideExtraneousWhitespace(in: string, withLastEditAt: indexRange) == nil)
    }

    @Test("returns non-nil", arguments: [
        // A leading-whitespace edit attaches to a preceding filter
        ("color: red", 6..<10, " red", "color:red", 6..<9),
        ("rarity!= common", 8..<15, " common", "rarity!=common", 8..<14),
        ("name: \"Serra", 5..<12, " \"Serra", "name:\"Serra", 5..<11),

        // Negated filter
        ("-color: blue", 7..<12, " blue", "-color:blue", 7..<11),

        // TODO: This is probably more surprising than helpful.
        // Elide whitespace even if it's not part of this edit
        ("color: red rarity: rare", 18..<23, " rare", "color:red rarity:rare", 17..<21),

        // Multiple filters in the edit all get elided
        ("(color: red or color: blue)", 7..<27, " red or color: blue)", "(color:red or color:blue)", 7..<25),
    ])
    func returnsNonNil(string: String, editRange: Range<Int>, checkString: String, expectedString: String, expectedRange: Range<Int>) throws {
        let indexRange = try #require(editRange.toStringIndices(in: string))
        try #require(string[indexRange] == checkString)
        let result = try #require(elideExtraneousWhitespace(in: string, withLastEditAt: indexRange))
        #expect(result.filter == nil)
        #expect(result.newText == expectedString)
        let expectedSelection = try #require(expectedRange.toStringIndices(in: result.newText))
        #expect(result.newSelection == expectedSelection)
    }
}

@Suite("quoteAdjacentBareWords")
struct QuoteAdjacentBareWordsTests {
    @Test("returns nil", arguments: [
        // After a basic filter: no consecutive bare words
        ("color!=red lightning", 10..<20, " lightning"),
        // After a regex filter: no consecutive bare words
        ("oracle:/lightning/ bolt", 18..<23, " bolt"),
        // After a non-bare term
        ("\"lightning\" bolt", 11..<16, " bolt"),
        // As the only term
        (" lightning", 0..<10, " lightning"),
        // Not a separate word
        ("lightningbolt", 9..<13, "bolt"),
        // Does not retroactively repair adjacent bare words if append isn't a bare word
        ("lightning bolt color:red", 14..<24, " color:red"),
        // Does not quote if the edit was prefix
        ("lightning bolt foo", 0..<10, "lightning "),
        // Does not quote if the edit was in the middle
        ("lightning bolt foo", 9..<14, " bolt"),
        // Does nothing if it's a zero-length edit
        ("lightning bolt", 14..<14, ""),
        // Does nothing if separating two words with a space
        ("lightning bolt", 9..<10, " "),
    ])
    func returnsNil(string: String, editRange: Range<Int>, checkString: String) throws {
        let indexRange = try #require(editRange.toStringIndices(in: string))
        try #require(string[indexRange] == checkString)
        #expect(quoteAdjacentBareWords(in: string, withLastEditAt: indexRange) == nil)
    }

    @Test("returns non-nil", arguments: [
        // One bare word with trailing additional space (some keyboards do this)
        ("lightning ", 0..<10, "lightning ", "\"lightning ", 11..<11),
        // Two bare words with trailing additional space
        ("lightning bolt ", 10..<15, "bolt ", "\"lightning bolt ", 16..<16),
        // Two bare words with the second bringing two spaces
        ("lightning bolt ", 9..<15, " bolt ", "\"lightning bolt ", 16..<16),
        // Two bare words with leading additional space (stock iOS keyboard does this)
        ("lightning bolt", 9..<14, " bolt", "\"lightning bolt", 15..<15),
        // Three bare words
        ("dark confidant soul", 14..<19, " soul", "\"dark confidant soul", 20..<20),
        // Bare words following a filter
        ("color:red lightning bolt", 19..<24, " bolt", "color:red \"lightning bolt", 25..<25),
        // Word with apostrophe
        ("urza's tower", 6..<12, " tower", "\"urza's tower", 13..<13),
        // Bare words with lots of extra space are collapsed
        ("lightning  bolt  ", 9..<17, "  bolt  ", "\"lightning bolt ", 16..<16),
    ])
    func returnsNonNil(string: String, editRange: Range<Int>, checkString: String, expectedString: String, expectedRange: Range<Int>) throws {
        let indexRange = try #require(editRange.toStringIndices(in: string))
        try #require(string[indexRange] == checkString)
        let result = try #require(quoteAdjacentBareWords(in: string, withLastEditAt: indexRange))
        #expect(result.filter == nil)
        #expect(result.newText == expectedString)
        let expectedSelection = try #require(expectedRange.toStringIndices(in: result.newText))
        #expect(result.newSelection == expectedSelection)
    }
}
