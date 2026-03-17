import SwiftUI
import Testing

@testable import MagicCardSearch

@Suite
struct DidAppendTests {
    // swiftlint:disable:next large_tuple
    @Test<[(String, String, Range<Int>?, Bool)]>("didAppend", arguments: [
        ("foo", "foo ", nil, true),
        ("foo", "foo ", 4..<4, true),
        ("foo", "foo ", 3..<4, true),
        ("foo", "foox", nil, false),
        ("foo", "foo ", 2..<2, false),
        ("foo", "foo  ", nil, false),
        ("foo", "fo", nil, false),
        ("fobar", "foobar", nil, false),
        ("fobar", "foobar", 3..<3, false),
    ])
    func didAppendCases(previous: String, current: String, selectionInts: Range<Int>?, expected: Bool) {
        let selection = selectionInts?.toStringIndices(in: current) ?? current.endIndexRange
        #expect(
            didAppend(characterFrom: [" "], to: previous, toCreate: current, withSelection: selection) == expected
        )
    }
}

@Suite
struct MaybeAutoUpdateSearchTextTests {
    @Test<[(String, String, Range<Int>?)]>("maybeAutoUpdateSearchText (nil)", arguments: [
        (
            "",
            "",
            nil,
        ),
        (
            "\"lightning ",
            "\"lightning  ",
            nil,
        ),
        (
            "(color:red",
            "(color:red ",
            nil,
        ),
        (
            "color:",
            "color: ",
            nil,
        ),
        (
            "colorred",
            "color:red",
            6..<6,
        ),
        (
            "color:red",
            "color:re",
            nil,
        ),
        (
            "color",
            "color:red",
            nil,
        ),
        (
            "lightning",
            "lightning'",
            nil,
        ),
        (
            "'lightning",
            "'lightning ",
            nil,
        ),
        (
            "\"lightning",
            "\"lightning ",
            nil,
        ),
        (
            "\"urza's sag\"",
            "\"urza's saga\"",
            12..<12,
        ),
        (
            "",
            ")",
            nil,
        ),
        (
            "",
            "/",
            nil,
        ),
    ])
    func maybeAutoUpdateSearchTextCasesNil(
        previous: String,
        current: String,
        selectionInts: Range<Int>?,
    ) {
        let selection = selectionInts?.toStringIndices(in: current) ?? current.endIndexRange
        #expect(maybeAutoUpdateSearchText(previous: previous, current: current, selection: selection) == nil)
    }

    // swiftlint:disable:next large_tuple
    @Test<[(String, String, Range<Int>?, (FilterQuery<FilterTerm>?, String, Range<Int>?))]>(
        "maybeAutoUpdateSearchText (non-nil)",
        arguments: [
            (
                " ",
                "  ",
                nil,
                (nil, "", nil)
            ),
            (
                "lightning",
                "lightning ",
                nil,
                (nil, "\"lightning ", nil)
            ),
            (
                "-lightning",
                "-lightning ",
                nil,
                (nil, "-\"lightning ", nil)
            ),
            (
                "urza's",
                "urza's ",
                nil,
                (nil, "\"urza's ", nil)
            ),
            (
                "\"urza's saga",
                "\"urza's saga\"",
                nil,
                (.term(.name(.positive, false, "urza's saga")), "", nil)
            ),
            (
                "oracle:/bolt",
                "oracle:/bolt/",
                nil,
                (.term(.regex(.positive, "oracle", .including, "bolt")), "", nil)
            ),
            (
                "color:",
                "color: red",
                nil,
                (nil, "color:red", 9..<9)
            ),
            (
                "color:",
                "color: red",
                9..<9,
                (nil, "color:red", 8..<8)
            ),
            (
                "(color:red or color:blue",
                "(color:red or color:blue)",
                nil,
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
    func maybeAutoUpdateSearchTextCases(
        previous: String,
        current: String,
        selectionInts: Range<Int>?,
        expected: (FilterQuery<FilterTerm>?, String, Range<Int>?)
    ) throws {
        let selection = selectionInts?.toStringIndices(in: current) ?? current.endIndexRange
        let result = try #require(maybeAutoUpdateSearchText(previous: previous, current: current, selection: selection))
        #expect(result == (
            expected.0,
            expected.1,
            expected.2.map { $0.toStringIndices(in: result.1)! },
        ))
    }
}
