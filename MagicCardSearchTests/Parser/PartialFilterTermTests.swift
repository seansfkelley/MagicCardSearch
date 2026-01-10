import Testing
@testable import MagicCardSearch

@Suite
struct PartialFilterTermTests {
    struct TestCase: CustomStringConvertible {
        let input: String
        let expectedPartial: PartialFilterTerm
        let expectedComplete: FilterTerm?

        var description: String { input }

        init(
            _ input: String,
            _ expectedPartial: PartialFilterTerm,
            _ expectedComplete: FilterTerm?,
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
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare("foo"))
            ),
            FilterTerm.name(.positive, false, "foo")
        ),

        TestCase(
            "teferi's",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare("teferi's"))
            ),
            FilterTerm.name(.positive, false, "teferi's")
        ),

        TestCase(
            "{p}",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare("{p}"))
            ),
            FilterTerm.name(.positive, false, "{p}")
        ),

        TestCase(
            // Names ending with comparison-like things parse as filters.
            "Fire!",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("Fire", .incompleteNotEqual, .bare(""))
            ),
            nil,
        ),

        TestCase(
            "lightning bolt",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare("lightning bolt"))
            ),
            FilterTerm.name(.positive, false, "lightning bolt")
        ),

        // MARK: - Exact name searches (!)
        TestCase(
            "!Fire",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(true, .bare("Fire"))
            ),
            FilterTerm.name(.positive, true, "Fire")
        ),

        TestCase(
            "!lightning",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(true, .bare("lightning"))
            ),
            FilterTerm.name(.positive, true, "lightning")
        ),

        TestCase(
            "!\"Lightning Bolt\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(true, .balanced(.doubleQuote, "Lightning Bolt"))
            ),
            FilterTerm.name(.positive, true, "Lightning Bolt")
        ),

        // MARK: - Quoted name searches
        TestCase(
            "'foo'",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .balanced(.singleQuote, "foo"))
            ),
            FilterTerm.name(.positive, false, "foo")
        ),

        TestCase(
            "\"lightning bolt\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .balanced(.doubleQuote, "lightning bolt"))
            ),
            FilterTerm.name(.positive, false, "lightning bolt")
        ),

        TestCase(
            "'lightning bolt'",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .balanced(.singleQuote, "lightning bolt"))
            ),
            FilterTerm.name(.positive, false, "lightning bolt")
        ),

        // MARK: - Unterminated quotes
        TestCase(
            "\"foo",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .unterminated(.doubleQuote, "foo"))
            ),
            nil
        ),

        TestCase(
            "'foo",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .unterminated(.singleQuote, "foo"))
            ),
            nil
        ),

        TestCase(
            "!\"lightning",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(true, .unterminated(.doubleQuote, "lightning"))
            ),
            nil
        ),

        // MARK: - Negated searches
        TestCase(
            "-lightning",
            PartialFilterTerm(
                polarity: .negative,
                content: .name(false, .bare("lightning"))
            ),
            FilterTerm.name(.negative, false, "lightning")
        ),

        TestCase(
            "-!lightning",
            PartialFilterTerm(
                polarity: .negative,
                content: .name(true, .bare("lightning"))
            ),
            FilterTerm.name(.negative, true, "lightning")
        ),

        TestCase(
            "-\"lightning bolt\"",
            PartialFilterTerm(
                polarity: .negative,
                content: .name(false, .balanced(.doubleQuote, "lightning bolt"))
            ),
            FilterTerm.name(.negative, false, "lightning bolt")
        ),

        // MARK: - Key-value filters with ":"
        TestCase(
            "set:foo",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("set", .including, .bare("foo"))
            ),
            FilterTerm.basic(.positive, "set", .including, "foo")
        ),

        TestCase(
            "type:creature",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("type", .including, .bare("creature"))
            ),
            FilterTerm.basic(.positive, "type", .including, "creature")
        ),

        TestCase(
            "oracle:\"draw a card\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "draw a card"))
            ),
            FilterTerm.basic(.positive, "oracle", .including, "draw a card")
        ),

        TestCase(
            "foo:\"bar",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("foo", .including, .unterminated(.doubleQuote, "bar"))
            ),
            nil,
        ),

        // MARK: - Negated key-value filters
        TestCase(
            "-type:creature",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("type", .including, .bare("creature"))
            ),
            FilterTerm.basic(.negative, "type", .including, "creature")
        ),

        TestCase(
            "-oracle:\"draw a card\"",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "draw a card"))
            ),
            FilterTerm.basic(.negative, "oracle", .including, "draw a card")
        ),

        // MARK: - Comparison operators
        TestCase(
            "s=bar",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("s", .equal, .bare("bar"))
            ),
            FilterTerm.basic(.positive, "s", .equal, "bar")
        ),

        TestCase(
            "mv>=bar",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("mv", .greaterThanOrEqual, .bare("bar"))
            ),
            FilterTerm.basic(.positive, "mv", .greaterThanOrEqual, "bar")
        ),

        TestCase(
            "m>{p/r}{g}",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("m", .greaterThan, .bare("{p/r}{g}"))
            ),
            FilterTerm.basic(.positive, "m", .greaterThan, "{p/r}{g}")
        ),

        TestCase(
            "power>3",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("power", .greaterThan, .bare("3"))
            ),
            FilterTerm.basic(.positive, "power", .greaterThan, "3")
        ),

        TestCase(
            "cmc<3",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("cmc", .lessThan, .bare("3"))
            ),
            FilterTerm.basic(.positive, "cmc", .lessThan, "3")
        ),

        TestCase(
            "cmc<=3",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("cmc", .lessThanOrEqual, .bare("3"))
            ),
            FilterTerm.basic(.positive, "cmc", .lessThanOrEqual, "3")
        ),

        TestCase(
            "color=red",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("color", .equal, .bare("red"))
            ),
            FilterTerm.basic(.positive, "color", .equal, "red")
        ),

        TestCase(
            "color!=red",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("color", .notEqual, .bare("red"))
            ),
            FilterTerm.basic(.positive, "color", .notEqual, "red")
        ),

        // MARK: - Incomplete comparisons
        TestCase(
            "foo:",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("foo", .including, .bare(""))
            ),
            nil
        ),

        TestCase(
            "power!",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("power", .incompleteNotEqual, .bare(""))
            ),
            nil
        ),

        TestCase(
            "power!value",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("power", .incompleteNotEqual, .bare("value"))
            ),
            nil
        ),

        TestCase(
            "cmc<",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("cmc", .lessThan, .bare(""))
            ),
            nil,
        ),

        TestCase(
            "power>",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("power", .greaterThan, .bare(""))
            ),
            nil,
        ),

        // MARK: - Regex filters (forward slashes)
        TestCase(
            "filtered:/regex with whitespace/",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("filtered", .including, .balanced(.forwardSlash, "regex with whitespace"))
            ),
            FilterTerm.regex(.positive, "filtered", .including, "regex with whitespace")
        ),

        TestCase(
            "name:/^lightning/",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("name", .including, .balanced(.forwardSlash, "^lightning"))
            ),
            FilterTerm.regex(.positive, "name", .including, "^lightning")
        ),

        TestCase(
            "-name:/^chain/",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("name", .including, .balanced(.forwardSlash, "^chain"))
            ),
            FilterTerm.regex(.negative, "name", .including, "^chain")
        ),

        // MARK: - Unterminated regex
        TestCase(
            "foo:/incomplete regex",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("foo", .including, .unterminated(.forwardSlash, "incomplete regex"))
            ),
            nil
        ),

        // MARK: - Unterminated quoted filters
        TestCase(
            "foo:\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("foo", .including, .unterminated(.doubleQuote, ""))
            ),
            nil
        ),

        TestCase(
            "oracle:'draw",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("oracle", .including, .unterminated(.singleQuote, "draw"))
            ),
            nil
        ),

        TestCase(
            "-oracle:\"draw",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("oracle", .including, .unterminated(.doubleQuote, "draw"))
            ),
            nil
        ),

        TestCase(
            "-oracle:'draw",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("oracle", .including, .unterminated(.singleQuote, "draw"))
            ),
            nil
        ),

        // MARK: - Empty strings
        TestCase(
            "",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare(""))
            ),
            FilterTerm.name(.positive, false, "")
        ),

        TestCase(
            " ",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare(" "))
            ),
            FilterTerm.name(.positive, false, " ")
        ),

        TestCase(
            "-",
            PartialFilterTerm(
                polarity: .negative,
                content: .name(false, .bare(""))
            ),
            FilterTerm.name(.negative, false, "")
        ),

        TestCase(
            "- ",
            PartialFilterTerm(
                polarity: .negative,
                content: .name(false, .bare(" "))
            ),
            FilterTerm.name(.negative, false, " ")
        ),

        // It is not our responsibility to deal with whitespace. Probably.
        TestCase(
            " -",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare(" -"))
            ),
            FilterTerm.name(.positive, false, " -")
        ),

        TestCase(
            "!",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(true, .bare(""))
            ),
            FilterTerm.name(.positive, true, "")
        ),

        TestCase(
            "type:",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("type", .including, .bare(""))
            ),
            nil,
        ),

        // MARK: - Mixed case field names
        TestCase(
            "Type:creature",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("Type", .including, .bare("creature"))
            ),
            FilterTerm.basic(.positive, "Type", .including, "creature")
        ),

        TestCase(
            "POWER>3",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("POWER", .greaterThan, .bare("3"))
            ),
            FilterTerm.basic(.positive, "POWER", .greaterThan, "3")
        ),

        // MARK: - Edge cases with special characters
        TestCase(
            "name:\"test:value\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("name", .including, .balanced(.doubleQuote, "test:value"))
            ),
            FilterTerm.basic(.positive, "name", .including, "test:value")
        ),

        TestCase(
            "oracle:\">3\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("oracle", .including, .balanced(.doubleQuote, ">3"))
            ),
            FilterTerm.basic(.positive, "oracle", .including, ">3")
        ),

        // MARK: - Regex with comparison operators
        TestCase(
            "name=/^L/",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("name", .equal, .balanced(.forwardSlash, "^L"))
            ),
            FilterTerm.regex(.positive, "name", .equal, "^L")
        ),

        TestCase(
            "power>/3/",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("power", .greaterThan, .balanced(.forwardSlash, "3"))
            ),
            FilterTerm.regex(.positive, "power", .greaterThan, "3")
        ),

        // MARK: - Single character inputs
        TestCase(
            "a",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare("a"))
            ),
            FilterTerm.name(.positive, false, "a")
        ),

        TestCase(
            "-a",
            PartialFilterTerm(
                polarity: .negative,
                content: .name(false, .bare("a"))
            ),
            FilterTerm.name(.negative, false, "a")
        ),

        // MARK: - Numbers and special characters in values
        TestCase(
            "cmc:3",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("cmc", .including, .bare("3"))
            ),
            FilterTerm.basic(.positive, "cmc", .including, "3")
        ),

        TestCase(
            "loyalty:\"5\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("loyalty", .including, .balanced(.doubleQuote, "5"))
            ),
            FilterTerm.basic(.positive, "loyalty", .including, "5")
        ),

        // MARK: - Multiple operators in sequence
        TestCase(
            "field:=value",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("field", .including, .bare("=value"))
            ),
            FilterTerm.basic(.positive, "field", .including, "=value")
        ),

        // MARK: - Spaces in unquoted values (edge case)
        TestCase(
            "oracle:draw a card",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("oracle", .including, .bare("draw a card"))
            ),
            FilterTerm.basic(.positive, "oracle", .including, "draw a card")
        ),

        // MARK: - Negation with all comparison types
        TestCase(
            "-power>=5",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("power", .greaterThanOrEqual, .bare("5"))
            ),
            FilterTerm.basic(.negative, "power", .greaterThanOrEqual, "5")
        ),

        TestCase(
            "-cmc<=2",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("cmc", .lessThanOrEqual, .bare("2"))
            ),
            FilterTerm.basic(.negative, "cmc", .lessThanOrEqual, "2")
        ),

        TestCase(
            "-color=blue",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("color", .equal, .bare("blue"))
            ),
            FilterTerm.basic(.negative, "color", .equal, "blue")
        ),

        TestCase(
            "-type!=land",
            PartialFilterTerm(
                polarity: .negative,
                content: .filter("type", .notEqual, .bare("land"))
            ),
            FilterTerm.basic(.negative, "type", .notEqual, "land")
        ),

        // MARK: - Empty quotes
        TestCase(
            "\"\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .balanced(.doubleQuote, ""))
            ),
            FilterTerm.name(.positive, false, "")
        ),

        TestCase(
            "''",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .balanced(.singleQuote, ""))
            ),
            FilterTerm.name(.positive, false, "")
        ),

        // Empty strings are permitted if they are explicitly quoted. Just for UX clarity when you
        // type one in, not because it means anything useful.
        TestCase(
            "oracle:\"\"",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("oracle", .including, .balanced(.doubleQuote, ""))
            ),
            FilterTerm.basic(.positive, "oracle", .including, "")
        ),

        TestCase(
            "name://",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("name", .including, .balanced(.forwardSlash, ""))
            ),
            FilterTerm.regex(.positive, "name", .including, "")
        ),

        TestCase(
            "/regexwithoutfilter/",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare("/regexwithoutfilter/")),
            ),
            FilterTerm.name(.positive, false, "/regexwithoutfilter/")
        ),

        TestCase(
            "/^test$/",
            PartialFilterTerm(
                polarity: .positive,
                content: .name(false, .bare("/^test$/")),
            ),
            FilterTerm.name(.positive, false, "/^test$/")
        ),

        TestCase(
            "type: creature",
            PartialFilterTerm(
                polarity: .positive,
                content: .filter("type", .including, .bare(" creature")),
            ),
            FilterTerm.basic(.positive, "type", .including, " creature")
        ),
    ])
    func parseAndConvert(testCase: TestCase) async throws {
        let actualPartial = PartialFilterTerm.from(testCase.input)
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
