import Testing
@testable import MagicCardSearch

@Suite("PartialSearchFilter Parsing Tests")
struct PartialSearchFilterTests {
    struct TestCase: CustomStringConvertible {
        let input: String
        let expectedPartial: PartialSearchFilter
        let expectedComplete: SearchFilter?

        var description: String { input }

        init(
            _ input: String,
            _ expectedPartial: PartialSearchFilter,
            _ expectedComplete: SearchFilter?,
        ) {
            self.input = input
            self.expectedPartial = expectedPartial
            self.expectedComplete = expectedComplete
        }
    }

    @Test("Parse and convert PartialSearchFilter", arguments: [
        // MARK: - Simple name searches
        TestCase(
            "foo",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare("foo"))
            ),
            SearchFilter.name(false, false, "foo")
        ),

        TestCase(
            "teferi's",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare("teferi's"))
            ),
            SearchFilter.name(false, false, "teferi's")
        ),

        TestCase(
            "{p}",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare("{p}"))
            ),
            SearchFilter.name(false, false, "{p}")
        ),

        TestCase(
            // Names ending with comparison-like things parse as filters.
            "Fire!",
            PartialSearchFilter(
                negated: false,
                content: .filter("Fire", .incompleteNotEqual, .bare(""))
            ),
            nil,
        ),

        TestCase(
            "lightning bolt",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare("lightning bolt"))
            ),
            SearchFilter.name(false, false, "lightning bolt")
        ),

        // MARK: - Exact name searches (!)
        TestCase(
            "!Fire",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .bare("Fire"))
            ),
            SearchFilter.name(false, true, "Fire")
        ),

        TestCase(
            "!lightning",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .bare("lightning"))
            ),
            SearchFilter.name(false, true, "lightning")
        ),

        TestCase(
            "!\"Lightning Bolt\"",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .balanced(.doubleQuote, "Lightning Bolt"))
            ),
            SearchFilter.name(false, true, "Lightning Bolt")
        ),

        // MARK: - Quoted name searches
        TestCase(
            "'foo'",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, "foo"))
            ),
            SearchFilter.name(false, false, "foo")
        ),

        TestCase(
            "\"lightning bolt\"",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.doubleQuote, "lightning bolt"))
            ),
            SearchFilter.name(false, false, "lightning bolt")
        ),

        TestCase(
            "'lightning bolt'",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, "lightning bolt"))
            ),
            SearchFilter.name(false, false, "lightning bolt")
        ),

        // MARK: - Unterminated quotes
        TestCase(
            "\"foo",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unterminated(.doubleQuote, "foo"))
            ),
            nil
        ),

        TestCase(
            "'foo",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unterminated(.singleQuote, "foo"))
            ),
            nil
        ),

        TestCase(
            "!\"lightning",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .unterminated(.doubleQuote, "lightning"))
            ),
            nil
        ),

        // MARK: - Negated searches
        TestCase(
            "-lightning",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .bare("lightning"))
            ),
            SearchFilter.name(true, false, "lightning")
        ),

        TestCase(
            "-!lightning",
            PartialSearchFilter(
                negated: true,
                content: .name(true, .bare("lightning"))
            ),
            SearchFilter.name(true, true, "lightning")
        ),

        TestCase(
            "-\"lightning bolt\"",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .balanced(.doubleQuote, "lightning bolt"))
            ),
            SearchFilter.name(true, false, "lightning bolt")
        ),

        // MARK: - Key-value filters with ":"
        TestCase(
            "set:foo",
            PartialSearchFilter(
                negated: false,
                content: .filter("set", .including, .bare("foo"))
            ),
            SearchFilter.basic(false, "set", .including, "foo")
        ),

        TestCase(
            "type:creature",
            PartialSearchFilter(
                negated: false,
                content: .filter("type", .including, .bare("creature"))
            ),
            SearchFilter.basic(false, "type", .including, "creature")
        ),

        TestCase(
            "oracle:\"draw a card\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "draw a card"))
            ),
            SearchFilter.basic(false, "oracle", .including, "draw a card")
        ),

        TestCase(
            "foo:\"bar",
            PartialSearchFilter(
                negated: false,
                content: .filter("foo", .including, .unterminated(.doubleQuote, "bar"))
            ),
            nil,
        ),

        // MARK: - Negated key-value filters
        TestCase(
            "-type:creature",
            PartialSearchFilter(
                negated: true,
                content: .filter("type", .including, .bare("creature"))
            ),
            SearchFilter.basic(true, "type", .including, "creature")
        ),

        TestCase(
            "-oracle:\"draw a card\"",
            PartialSearchFilter(
                negated: true,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "draw a card"))
            ),
            SearchFilter.basic(true, "oracle", .including, "draw a card")
        ),

        // MARK: - Comparison operators
        TestCase(
            "s=bar",
            PartialSearchFilter(
                negated: false,
                content: .filter("s", .equal, .bare("bar"))
            ),
            SearchFilter.basic(false, "s", .equal, "bar")
        ),

        TestCase(
            "mv>=bar",
            PartialSearchFilter(
                negated: false,
                content: .filter("mv", .greaterThanOrEqual, .bare("bar"))
            ),
            SearchFilter.basic(false, "mv", .greaterThanOrEqual, "bar")
        ),

        TestCase(
            "m>{p/r}{g}",
            PartialSearchFilter(
                negated: false,
                content: .filter("m", .greaterThan, .bare("{p/r}{g}"))
            ),
            SearchFilter.basic(false, "m", .greaterThan, "{p/r}{g}")
        ),

        TestCase(
            "power>3",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThan, .bare("3"))
            ),
            SearchFilter.basic(false, "power", .greaterThan, "3")
        ),

        TestCase(
            "cmc<3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .lessThan, .bare("3"))
            ),
            SearchFilter.basic(false, "cmc", .lessThan, "3")
        ),

        TestCase(
            "cmc<=3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .lessThanOrEqual, .bare("3"))
            ),
            SearchFilter.basic(false, "cmc", .lessThanOrEqual, "3")
        ),

        TestCase(
            "color=red",
            PartialSearchFilter(
                negated: false,
                content: .filter("color", .equal, .bare("red"))
            ),
            SearchFilter.basic(false, "color", .equal, "red")
        ),

        TestCase(
            "color!=red",
            PartialSearchFilter(
                negated: false,
                content: .filter("color", .notEqual, .bare("red"))
            ),
            SearchFilter.basic(false, "color", .notEqual, "red")
        ),

        // MARK: - Incomplete comparisons
        TestCase(
            "foo:",
            PartialSearchFilter(
                negated: false,
                content: .filter("foo", .including, .bare(""))
            ),
            nil
        ),

        TestCase(
            "power!",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .incompleteNotEqual, .bare(""))
            ),
            nil
        ),

        TestCase(
            "power!value",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .incompleteNotEqual, .bare("value"))
            ),
            nil
        ),

        TestCase(
            "cmc<",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .lessThan, .bare(""))
            ),
            nil,
        ),

        TestCase(
            "power>",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThan, .bare(""))
            ),
            nil,
        ),

        // MARK: - Regex filters (forward slashes)
        TestCase(
            "filtered:/regex with whitespace/",
            PartialSearchFilter(
                negated: false,
                content: .filter("filtered", .including, .balanced(.forwardSlash, "regex with whitespace"))
            ),
            SearchFilter.regex(false, "filtered", .including, "regex with whitespace")
        ),

        TestCase(
            "name:/^lightning/",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.forwardSlash, "^lightning"))
            ),
            SearchFilter.regex(false, "name", .including, "^lightning")
        ),

        TestCase(
            "-name:/^chain/",
            PartialSearchFilter(
                negated: true,
                content: .filter("name", .including, .balanced(.forwardSlash, "^chain"))
            ),
            SearchFilter.regex(true, "name", .including, "^chain")
        ),

        // MARK: - Unterminated regex
        TestCase(
            "foo:/incomplete regex",
            PartialSearchFilter(
                negated: false,
                content: .filter("foo", .including, .unterminated(.forwardSlash, "incomplete regex"))
            ),
            nil
        ),

        // MARK: - Unterminated quoted filters
        TestCase(
            "foo:\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("foo", .including, .unterminated(.doubleQuote, ""))
            ),
            nil
        ),

        TestCase(
            "oracle:'draw",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .unterminated(.singleQuote, "draw"))
            ),
            nil
        ),

        TestCase(
            "-oracle:\"draw",
            PartialSearchFilter(
                negated: true,
                content: .filter("oracle", .including, .unterminated(.doubleQuote, "draw"))
            ),
            nil
        ),

        TestCase(
            "-oracle:'draw",
            PartialSearchFilter(
                negated: true,
                content: .filter("oracle", .including, .unterminated(.singleQuote, "draw"))
            ),
            nil
        ),

        // MARK: - Empty strings
        TestCase(
            "",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare(""))
            ),
            SearchFilter.name(false, false, "")
        ),

        TestCase(
            " ",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare(" "))
            ),
            SearchFilter.name(false, false, " ")
        ),

        TestCase(
            "-",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .bare(""))
            ),
            SearchFilter.name(true, false, "")
        ),

        TestCase(
            "- ",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .bare(" "))
            ),
            SearchFilter.name(true, false, " ")
        ),

        // It is not our responsibility to deal with whitespace. Probably.
        TestCase(
            " -",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare(" -"))
            ),
            SearchFilter.name(false, false, " -")
        ),

        TestCase(
            "!",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .bare(""))
            ),
            SearchFilter.name(false, true, "")
        ),

        TestCase(
            "type:",
            PartialSearchFilter(
                negated: false,
                content: .filter("type", .including, .bare(""))
            ),
            nil,
        ),

        // MARK: - Mixed case field names
        TestCase(
            "Type:creature",
            PartialSearchFilter(
                negated: false,
                content: .filter("Type", .including, .bare("creature"))
            ),
            SearchFilter.basic(false, "Type", .including, "creature")
        ),

        TestCase(
            "POWER>3",
            PartialSearchFilter(
                negated: false,
                content: .filter("POWER", .greaterThan, .bare("3"))
            ),
            SearchFilter.basic(false, "POWER", .greaterThan, "3")
        ),

        // MARK: - Edge cases with special characters
        TestCase(
            "name:\"test:value\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.doubleQuote, "test:value"))
            ),
            SearchFilter.basic(false, "name", .including, "test:value")
        ),

        TestCase(
            "oracle:\">3\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, ">3"))
            ),
            SearchFilter.basic(false, "oracle", .including, ">3")
        ),

        // MARK: - Regex with comparison operators
        TestCase(
            "name=/^L/",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .equal, .balanced(.forwardSlash, "^L"))
            ),
            SearchFilter.regex(false, "name", .equal, "^L")
        ),

        TestCase(
            "power>/3/",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThan, .balanced(.forwardSlash, "3"))
            ),
            SearchFilter.regex(false, "power", .greaterThan, "3")
        ),

        // MARK: - Single character inputs
        TestCase(
            "a",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare("a"))
            ),
            SearchFilter.name(false, false, "a")
        ),

        TestCase(
            "-a",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .bare("a"))
            ),
            SearchFilter.name(true, false, "a")
        ),

        // MARK: - Numbers and special characters in values
        TestCase(
            "cmc:3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .including, .bare("3"))
            ),
            SearchFilter.basic(false, "cmc", .including, "3")
        ),

        TestCase(
            "loyalty:\"5\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("loyalty", .including, .balanced(.doubleQuote, "5"))
            ),
            SearchFilter.basic(false, "loyalty", .including, "5")
        ),

        // MARK: - Multiple operators in sequence
        TestCase(
            "field:=value",
            PartialSearchFilter(
                negated: false,
                content: .filter("field", .including, .bare("=value"))
            ),
            SearchFilter.basic(false, "field", .including, "=value")
        ),

        // MARK: - Spaces in unquoted values (edge case)
        TestCase(
            "oracle:draw a card",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .bare("draw a card"))
            ),
            SearchFilter.basic(false, "oracle", .including, "draw a card")
        ),

        // MARK: - Negation with all comparison types
        TestCase(
            "-power>=5",
            PartialSearchFilter(
                negated: true,
                content: .filter("power", .greaterThanOrEqual, .bare("5"))
            ),
            SearchFilter.basic(true, "power", .greaterThanOrEqual, "5")
        ),

        TestCase(
            "-cmc<=2",
            PartialSearchFilter(
                negated: true,
                content: .filter("cmc", .lessThanOrEqual, .bare("2"))
            ),
            SearchFilter.basic(true, "cmc", .lessThanOrEqual, "2")
        ),

        TestCase(
            "-color=blue",
            PartialSearchFilter(
                negated: true,
                content: .filter("color", .equal, .bare("blue"))
            ),
            SearchFilter.basic(true, "color", .equal, "blue")
        ),

        TestCase(
            "-type!=land",
            PartialSearchFilter(
                negated: true,
                content: .filter("type", .notEqual, .bare("land"))
            ),
            SearchFilter.basic(true, "type", .notEqual, "land")
        ),

        // MARK: - Empty quotes
        TestCase(
            "\"\"",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.doubleQuote, ""))
            ),
            SearchFilter.name(false, false, "")
        ),

        TestCase(
            "''",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, ""))
            ),
            SearchFilter.name(false, false, "")
        ),

        // Empty strings are permitted if they are explicitly quoted. Just for UX clarity when you
        // type one in, not because it means anything useful.
        TestCase(
            "oracle:\"\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, ""))
            ),
            SearchFilter.basic(false, "oracle", .including, "")
        ),

        TestCase(
            "name://",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.forwardSlash, ""))
            ),
            SearchFilter.regex(false, "name", .including, "")
        ),

        TestCase(
            "/regexwithoutfilter/",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare("/regexwithoutfilter/")),
            ),
            SearchFilter.name(false, false, "/regexwithoutfilter/")
        ),

        TestCase(
            "/^test$/",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .bare("/^test$/")),
            ),
            SearchFilter.name(false, false, "/^test$/")
        ),

        TestCase(
            "type: creature",
            PartialSearchFilter(
                negated: false,
                content: .filter("type", .including, .bare(" creature")),
            ),
            SearchFilter.basic(false, "type", .including, " creature")
        ),
    ])
    func parseAndConvert(testCase: TestCase) async throws {
        let actualPartial = PartialSearchFilter.from(testCase.input)
        #expect(actualPartial.description == testCase.input)

        #expect(
            actualPartial == testCase.expectedPartial,
            "Parsing '\(testCase.input)' failed"
        )

        let actualComplete = actualPartial.toComplete()
        #expect(
            actualComplete == testCase.expectedComplete,
            "Converting '\(testCase.input)' to SearchFilter failed"
        )
    }
}
