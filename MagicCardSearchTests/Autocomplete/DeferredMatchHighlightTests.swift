import FuzzyMatch
import Testing
@testable import MagicCardSearch

@Suite
struct DeferredMatchHighlightTests {
    @Test
    func highlightsEmptyQueryProducesNoRanges() {
        let matcher = FuzzyMatcher()
        var match = DeferredMatchHighlight(value: "Lightning Bolt", string: "Lightning Bolt", matcher: matcher, query: matcher.prepare(""))
        #expect(match.highlights.isEmpty)
    }

    @Test
    func highlightsEmptyStringProducesNoRanges() {
        let matcher = FuzzyMatcher()
        var match = DeferredMatchHighlight(value: "", string: "", matcher: matcher, query: matcher.prepare("bolt"))
        #expect(match.highlights.isEmpty)
    }

    @Test
    func highlightsExactSubstring() {
        let matcher = FuzzyMatcher()
        var match = DeferredMatchHighlight(value: "Lightning Bolt", string: "Lightning Bolt", matcher: matcher, query: matcher.prepare("bolt"))
        let highlighted = match.highlights.map { String("Lightning Bolt"[$0]) }
        #expect(highlighted == ["Bolt"])
    }
}
