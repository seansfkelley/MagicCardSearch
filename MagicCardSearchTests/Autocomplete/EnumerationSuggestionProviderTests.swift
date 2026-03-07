import Testing
import Foundation
@testable import MagicCardSearch

private let emptyCatalogData = EnumerationCatalogData(
    catalogs: [:],
    sets: nil,
    artTags: nil,
    oracleTags: nil
)

struct EnumerationSuggestionProviderTests {
    private func extractFilters(_ suggestions: [Suggestion]) -> [FilterQuery<FilterTerm>] {
        suggestions.compactMap {
            if case .filter(let highlighted) = $0.content { highlighted.value } else { nil }
        }
    }

    @Test<[(PartialFilterTerm, [FilterQuery<FilterTerm>])]>("getSuggestions", arguments: [
        (
            // gives all values, in alphabetical order, if no value part is given
            PartialFilterTerm(polarity: .positive, content: .filter("manavalue", .equal, .bare(""))),
            [
                .term(FilterTerm.basic(.positive, "manavalue", .equal, "even")),
                .term(FilterTerm.basic(.positive, "manavalue", .equal, "odd")),
            ]
        ),
        (
            // narrows based on substring match, preferring shorter strings when they are both prefixes
            PartialFilterTerm(polarity: .positive, content: .filter("is", .including, .bare("scry"))),
            [
                .term(FilterTerm.basic(.positive, "is", .including, "scryland")),
                .term(FilterTerm.basic(.positive, "is", .including, "scryfallpreview")),
            ]
        ),
        (
            // narrows with any substring, not just prefix, also, doesn't care about operator
            PartialFilterTerm(polarity: .positive, content: .filter("format", .greaterThanOrEqual, .bare("less"))),
            [
                .term(FilterTerm.basic(.positive, "format", .greaterThanOrEqual, "timeless")),
            ]
        ),
        (
            // the negation operator is preserved
            PartialFilterTerm(polarity: .negative, content: .filter("is", .including, .bare("scry"))),
            [
                .term(FilterTerm.basic(.negative, "is", .including, "scryland")),
                .term(FilterTerm.basic(.negative, "is", .including, "scryfallpreview")),
            ]
        ),
        (
            // case-insensitive
            PartialFilterTerm(polarity: .positive, content: .filter("foRMat", .greaterThanOrEqual, .bare("lESs"))),
            [
                .term(FilterTerm.basic(.positive, "format", .greaterThanOrEqual, "timeless")),
            ]
        ),
        (
            // non-enumerable filter type yields no options
            PartialFilterTerm(polarity: .positive, content: .filter("oracle", .equal, .bare(""))),
            []
        ),
        (
            // incomplete filter types yield no suggestions
            PartialFilterTerm(polarity: .positive, content: .name(false, .bare("form"))),
            []
        ),
        (
            // unknown filter types yield no suggestions
            PartialFilterTerm(polarity: .positive, content: .filter("foobar", .including, .bare(""))),
            []
        ),
        (
            // incomplete operator is not completeable
            PartialFilterTerm(polarity: .positive, content: .filter("format", .incompleteNotEqual, .bare(""))),
            []
        ),
    ])
    func getSuggestions(partial: PartialFilterTerm, expected: [FilterQuery<FilterTerm>]) async {
        let provider = EnumerationSuggestionProvider()
        let actual = await provider.getSuggestions(for: partial, catalogData: emptyCatalogData, searchTerm: "", limit: 100)
        let actualFilters = extractFilters(actual)
        #expect(actualFilters == expected)
        #expect(actual.allSatisfy { $0.source == .enumeration })
    }
}
