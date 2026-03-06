import Testing
@testable import MagicCardSearch

@Suite
struct WithHighlightedStringTests {
    private func highlightedSubstrings(_ string: String, searchTerm: String) -> [String] {
        var whs = WithHighlightedString(value: string, string: string, searchTerm: searchTerm)
        return whs.highlights.map { String(string[$0]) }
    }

    @Test func contiguousSubstringMatch() {
        #expect(highlightedSubstrings("Lightning Bolt", searchTerm: "bolt") == ["Bolt"])
    }

    @Test func disjointCharacterMatches() {
        #expect(highlightedSubstrings("Counterspell", searchTerm: "cnsp") == ["C", "n", "sp"])
    }

    @Test func caseInsensitive() {
        #expect(highlightedSubstrings("Lightning Bolt", searchTerm: "BOLT") == ["Bolt"])
    }

    @Test func emptySearchTermReturnsEmpty() {
        #expect(highlightedSubstrings("Lightning Bolt", searchTerm: "") == [])
    }

    @Test func emptyStringReturnsEmpty() {
        #expect(highlightedSubstrings("", searchTerm: "bolt") == [])
    }

    @Test func searchCharNotInStringIsSkipped() {
        #expect(highlightedSubstrings("color:red", searchTerm: "xred") == ["red"])
    }

    @Test func entireStringMatched() {
        #expect(highlightedSubstrings("red", searchTerm: "red") == ["red"])
    }

    @Test func noMatchingCharactersReturnsEmpty() {
        #expect(highlightedSubstrings("Lightning Bolt", searchTerm: "xyz") == [])
    }

    @Test func prefixMatch() {
        #expect(highlightedSubstrings("Lightning Bolt", searchTerm: "light") == ["Light"])
    }

    @Test func multipleDisjointGroups() {
        #expect(highlightedSubstrings("Firebolt", searchTerm: "fbt") == ["F", "bolt"])
    }

    @Test func repeatedCharactersMatchGreedily() {
        #expect(highlightedSubstrings("aabba", searchTerm: "aa") == ["aa"])
    }

    @Test func searchTermLongerThanString() {
        #expect(highlightedSubstrings("ab", searchTerm: "abcdef") == ["ab"])
    }
}
