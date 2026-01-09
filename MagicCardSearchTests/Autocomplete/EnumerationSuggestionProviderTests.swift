import Testing
import Foundation
import SQLiteData
import DependenciesTestSupport
@testable import MagicCardSearch

@Suite(.dependency(\.defaultDatabase, try appDatabase()))
@MainActor
struct EnumerationSuggestionProviderTests {
    @Dependency(\.defaultDatabase) var database
    var provider: EnumerationSuggestionProvider!

    init() {
        provider = EnumerationSuggestionProvider(scryfallCatalogs: ScryfallCatalogs(database: database))
    }

    @Test<[(PartialFilterTerm, [EnumerationSuggestion])]>("getSuggestions", arguments: [
        (
            // gives all values, in alphabetical order, if no value part is given
            PartialFilterTerm(negated: false, content: .filter("manavalue", .equal, .bare(""))),
            [
                .init(
                    filter: SearchFilter.basic(false, "manavalue", .equal, "even"),
                    matchRange: nil,
                    prefixKind: .none,
                    suggestionLength: 4
                ),
                .init(
                    filter: SearchFilter.basic(false, "manavalue", .equal, "odd"),
                    matchRange: nil,
                    prefixKind: .none,
                    suggestionLength: 3
                ),
            ],
        ),
        (
            // narrows based on substring match, preferring shorter strings when they are both prefixes
            PartialFilterTerm(negated: false, content: .filter("is", .including, .bare("scry"))),
            [
                .init(
                    filter: SearchFilter.basic(false, "is", .including, "scryland"),
                    matchRange: "is:scryland".range(of: "scry"),
                    prefixKind: .actual,
                    suggestionLength: 8
                ),
                .init(
                    filter: SearchFilter.basic(false, "is", .including, "scryfallpreview"),
                    matchRange: "is:scryfallpreview".range(of: "scry"),
                    prefixKind: .actual,
                    suggestionLength: 15
                ),
            ],
        ),
        (
            // narrows with any substring, not just prefix, also, doesn't care about operator
            PartialFilterTerm(negated: false, content: .filter("format", .greaterThanOrEqual, .bare("less"))),
            [
                .init(
                    filter: SearchFilter.basic(false, "format", .greaterThanOrEqual, "timeless"),
                    matchRange: "format>=timeless".range(of: "less"),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
            ],
        ),
        (
            // the negation operator is preserved and does not affect behavior, but is included in the result
            PartialFilterTerm(negated: true, content: .filter("is", .including, .bare("scry"))),
            [
                .init(
                    filter: SearchFilter.basic(true, "is", .including, "scryland"),
                    matchRange: "-is:scryland".range(of: "scry"),
                    prefixKind: .effective,
                    suggestionLength: 8
                ),
                .init(
                    filter: SearchFilter.basic(true, "is", .including, "scryfallpreview"),
                    matchRange: "-is:scryfallpreview".range(of: "scry"),
                    prefixKind: .effective,
                    suggestionLength: 15
                ),
            ],
        ),
        (
            // case-insensitive
            PartialFilterTerm(negated: false, content: .filter("foRMat", .greaterThanOrEqual, .bare("lESs"))),
            [
                .init(
                    filter: SearchFilter.basic(false, "format", .greaterThanOrEqual, "timeless"),
                    matchRange: "format>=timeless".range(of: "less", options: .caseInsensitive),
                    prefixKind: .none,
                    suggestionLength: 8
                ),
            ],
        ),
        (
            // non-enumerable filter type yields no options
            PartialFilterTerm(negated: false, content: .filter("oracle", .equal, .bare(""))),
            [],
        ),
        (
            // incomplete filter types yield no suggestions
            PartialFilterTerm(negated: false, content: .name(false, .bare("form"))),
            [],
        ),
        (
            // unknown filter types yield no suggestions
            PartialFilterTerm(negated: false, content: .filter("foobar", .including, .bare(""))),
            [],
        ),
        (
            // incomplete operator is not completeable
            PartialFilterTerm(negated: false, content: .filter("format", .incompleteNotEqual, .bare(""))),
            [],
        ),
    ])
    func getSuggestions(partial: PartialFilterTerm, expected: [EnumerationSuggestion]) {
        let actual = provider.getSuggestions(for: partial, excluding: [], limit: 100)
        #expect(actual == expected)
    }
}
