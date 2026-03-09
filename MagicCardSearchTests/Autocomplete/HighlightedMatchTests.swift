import Testing
@testable import MagicCardSearch

@Suite
struct HighlightedMatchTests {
    // swiftlint:disable comma
    @Test(arguments: [
        ("Lightning Bolt",  "bolt",     ["Bolt"]),
        ("Counterspell",    "cnsp",     ["C", "n", "sp"]),
        ("Lightning Bolt",  "BOLT",     ["Bolt"]),
        ("Lightning Bolt",  "",         []),
        ("",                "bolt",     []),
        ("color:red",       "xred",     ["red"]),
        ("uncommon",        "funcomm",  ["uncomm"]),
        ("uncommon",        "uxncxomm", ["uncomm"]),
        ("red",             "red",      ["red"]),
        ("Lightning Bolt",  "xyz",      []),
        ("Lightning Bolt",  "light",    ["Light"]),
        ("format:modern",   "mod",      ["mod"]),
        ("Firebolt",        "fbt",      ["F", "b", "t"]),
        ("aabba",           "aa",       ["aa"]),
        ("ab",              "abcdef",   ["ab"]),
    ])
    // swiftlint:enable comma
    func highlights(string: String, query: String, expected: [String]) {
        var match = HighlightedMatch(value: string, string: string, query: query)
        let result = match.highlights.map { String(string[$0]) }
        #expect(result == expected)
    }
}
