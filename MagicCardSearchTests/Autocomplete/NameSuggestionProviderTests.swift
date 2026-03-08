import Testing
@testable import MagicCardSearch

// MARK: - Tests

struct NameSuggestionProviderTests {
    struct TestCase: Sendable, CustomStringConvertible {
        let description: String
        let partial: PartialFilterTerm
        let mockResults: [String]
        let expectedFilters: [FilterQuery<FilterTerm>]

        init(_ description: String, _ partial: PartialFilterTerm, _ mockResults: [String], _ expectedFilters: [FilterQuery<FilterTerm>]) {
            self.description = description
            self.partial = partial
            self.mockResults = mockResults
            self.expectedFilters = expectedFilters
        }
    }

    private func extractFilters(_ suggestions: [Suggestion]) -> [FilterQuery<FilterTerm>] {
        suggestions.compactMap {
            if case .filter(let highlighted) = $0.content { highlighted.value } else { nil }
        }
    }

    @Test("getSuggestions", arguments: [
        TestCase(
            "early-abort and return nothing if it looks like a non-name filter",
            PartialFilterTerm(polarity: .positive, content: .filter("foo", .including, .bare(""))),
            ["foobar"],
            []
        ),
        TestCase(
            "early-abort and return nothing if it's a name-type filter with less than 2 characters",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("f"))),
            ["foobar"],
            []
        ),
        TestCase(
            "return results if it's a name-type filter, adding quotes where necessary",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt", "Someone's Bolt"],
            [
                .term(.basic(.positive, "name", Comparison.including, "Firebolt")),
                .term(.basic(.positive, "name", Comparison.including, "Lightning Bolt")),
                .term(.basic(.positive, "name", Comparison.including, "Someone's Bolt")),
            ]
        ),
        TestCase(
            "is case-insensitive",
            PartialFilterTerm(polarity: .positive, content: .filter("nAmE", .including, .bare("boLT"))),
            ["Firebolt"],
            [.term(.basic(.positive, "name", Comparison.including, "Firebolt"))]
        ),
        TestCase(
            "respects the operator used",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .equal, .bare("bolt"))),
            ["Firebolt"],
            [.term(.basic(.positive, "name", Comparison.equal, "Firebolt"))]
        ),
        TestCase(
            "supports incomplete terms",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .equal, .unterminated(.singleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.basic(.positive, "name", Comparison.equal, "Firebolt")),
                .term(.basic(.positive, "name", Comparison.equal, "Lightning Bolt")),
            ]
        ),
        TestCase(
            "return results if it's quoted without a filter",
            PartialFilterTerm(polarity: .positive, content: .name(false, .unterminated(.doubleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.name(.positive, true, "Firebolt")),
                .term(.name(.positive, true, "Lightning Bolt")),
            ]
        ),
        TestCase(
            "return results if it's a literal name match",
            PartialFilterTerm(polarity: .positive, content: .name(true, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.name(.positive, true, "Firebolt")),
                .term(.name(.positive, true, "Lightning Bolt")),
            ]
        ),
        TestCase(
            "return results with negative polarity",
            PartialFilterTerm(polarity: .negative, content: .name(true, .unterminated(.doubleQuote, "bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.name(.negative, true, "Firebolt")),
                .term(.name(.negative, true, "Lightning Bolt")),
            ]
        ),
        TestCase(
            "pass through all results from the matcher",
            PartialFilterTerm(polarity: .positive, content: .filter("name", .including, .bare("foo"))),
            ["Wooded Foothills", "Shivan Reef"],
            [
                .term(.basic(.positive, "name", Comparison.including, "Wooded Foothills")),
                .term(.basic(.positive, "name", Comparison.including, "Shivan Reef")),
            ]
        ),
        TestCase(
            "return matches even if it doesn't look like a filter",
            PartialFilterTerm(polarity: .positive, content: .name(false, .bare("bolt"))),
            ["Firebolt", "Lightning Bolt"],
            [
                .term(.name(.positive, true, "Firebolt")),
                .term(.name(.positive, true, "Lightning Bolt")),
            ]
        ),
    ])
    func getSuggestions(testCase: TestCase) {
        let actual = nameSuggestions(for: testCase.partial, in: testCase.mockResults, searchTerm: "", limit: Int.max)
        let actualFilters = extractFilters(actual)
        #expect(actualFilters == testCase.expectedFilters, "\(testCase.description)")
        #expect(actual.allSatisfy { $0.source == .name })
    }

    // TODO: Test limit parameter.
}
