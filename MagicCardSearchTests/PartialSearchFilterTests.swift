//
//  PartialSearchFilterTests.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-21.
//
import Testing
@testable import MagicCardSearch

@Suite("PartialSearchFilter Parsing Tests")
struct PartialSearchFilterTests {
    struct TestCase {
        let input: String
        let expectedPartial: PartialSearchFilter
        let expectedComplete: SearchFilter?
        
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
                content: .name(false, .unquoted("foo"))
            ),
            .basic(.name("foo", false))
        ),
        
        TestCase(
            "lightning",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unquoted("lightning"))
            ),
            .basic(.name("lightning", false))
        ),
        
        TestCase(
            "teferi's",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unquoted("teferi's"))
            ),
            .basic(.name("teferi's", false))
        ),
        
        TestCase(
            "{p}",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unquoted("{p}"))
            ),
            .basic(.name("{p}", false))
        ),
        
        TestCase(
            // Names ending with comparison-like things parse as filters.
            "Fire!",
            PartialSearchFilter(
                negated: false,
                content: .filter("Fire", .incompleteNotEqual, .unquoted(""))
            ),
            nil,
        ),
        
        TestCase(
            "lightning bolt",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unquoted("lightning bolt"))
            ),
            .basic(.name("lightning bolt", false))
        ),
        
        // MARK: - Exact name searches (!)
        TestCase(
            "!Fire",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .unquoted("Fire"))
            ),
            .basic(.name("Fire", true))
        ),
        
        TestCase(
            "!lightning",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .unquoted("lightning"))
            ),
            .basic(.name("lightning", true))
        ),
        
        TestCase(
            "!\"Lightning Bolt\"",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .balanced(.doubleQuote, "Lightning Bolt"))
            ),
            .basic(.name("Lightning Bolt", true))
        ),
        
        // MARK: - Quoted name searches
        TestCase(
            "'foo'",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, "foo"))
            ),
            .basic(.name("foo", false))
        ),
        
        TestCase(
            "\"lightning bolt\"",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.doubleQuote, "lightning bolt"))
            ),
            .basic(.name("lightning bolt", false))
        ),
        
        TestCase(
            "'lightning bolt'",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, "lightning bolt"))
            ),
            .basic(.name("lightning bolt", false))
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
            "\"lightning",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unterminated(.doubleQuote, "lightning"))
            ),
            nil
        ),
        
        TestCase(
            "'lightning",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unterminated(.singleQuote, "lightning"))
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
                content: .name(false, .unquoted("lightning"))
            ),
            .negated(.name("lightning", false))
        ),
        
        TestCase(
            "-!lightning",
            PartialSearchFilter(
                negated: true,
                content: .name(true, .unquoted("lightning"))
            ),
            .negated(.name("lightning", true))
        ),
        
        TestCase(
            "-\"lightning bolt\"",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .balanced(.doubleQuote, "lightning bolt"))
            ),
            .negated(.name("lightning bolt", false))
        ),
        
        // MARK: - Key-value filters with ":"
        TestCase(
            "set:foo",
            PartialSearchFilter(
                negated: false,
                content: .filter("set", .including, .unquoted("foo"))
            ),
            .basic(.keyValue("set", .including, "foo"))
        ),
        
        TestCase(
            "type:creature",
            PartialSearchFilter(
                negated: false,
                content: .filter("type", .including, .unquoted("creature"))
            ),
            .basic(.keyValue("type", .including, "creature"))
        ),
        
        TestCase(
            "oracle:draw",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .unquoted("draw"))
            ),
            .basic(.keyValue("oracle", .including, "draw"))
        ),
        
        TestCase(
            "oracle:\"draw a card\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "draw a card"))
            ),
            .basic(.keyValue("oracle", .including, "draw a card"))
        ),
        
        TestCase(
            "foo:\"bar",
            PartialSearchFilter(
                negated: false,
                content: .filter("foo", .including, .unterminated(.doubleQuote, "bar"))
            ),
            nil,
        ),
        
        TestCase(
            "name:lightning",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .unquoted("lightning"))
            ),
            .basic(.keyValue("name", .including, "lightning"))
        ),
        
        // MARK: - Negated key-value filters
        TestCase(
            "-type:creature",
            PartialSearchFilter(
                negated: true,
                content: .filter("type", .including, .unquoted("creature"))
            ),
            .negated(.keyValue("type", .including, "creature"))
        ),
        
        TestCase(
            "-oracle:\"draw a card\"",
            PartialSearchFilter(
                negated: true,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "draw a card"))
            ),
            .negated(.keyValue("oracle", .including, "draw a card"))
        ),
        
        // MARK: - Comparison operators
        TestCase(
            "s=bar",
            PartialSearchFilter(
                negated: false,
                content: .filter("s", .equal, .unquoted("bar"))
            ),
            .basic(.keyValue("s", .equal, "bar"))
        ),
        
        TestCase(
            "mv>=bar",
            PartialSearchFilter(
                negated: false,
                content: .filter("mv", .greaterThanOrEqual, .unquoted("bar"))
            ),
            .basic(.keyValue("mv", .greaterThanOrEqual, "bar"))
        ),
        
        TestCase(
            "m>{p/r}{g}",
            PartialSearchFilter(
                negated: false,
                content: .filter("m", .greaterThan, .unquoted("{p/r}{g}"))
            ),
            .basic(.keyValue("m", .greaterThan, "{p/r}{g}"))
        ),
        
        TestCase(
            "power>3",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThan, .unquoted("3"))
            ),
            .basic(.keyValue("power", .greaterThan, "3"))
        ),
        
        TestCase(
            "power>=3",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThanOrEqual, .unquoted("3"))
            ),
            .basic(.keyValue("power", .greaterThanOrEqual, "3"))
        ),
        
        TestCase(
            "cmc<3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .lessThan, .unquoted("3"))
            ),
            .basic(.keyValue("cmc", .lessThan, "3"))
        ),
        
        TestCase(
            "cmc<=3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .lessThanOrEqual, .unquoted("3"))
            ),
            .basic(.keyValue("cmc", .lessThanOrEqual, "3"))
        ),
        
        TestCase(
            "color=red",
            PartialSearchFilter(
                negated: false,
                content: .filter("color", .equal, .unquoted("red"))
            ),
            .basic(.keyValue("color", .equal, "red"))
        ),
        
        TestCase(
            "color!=red",
            PartialSearchFilter(
                negated: false,
                content: .filter("color", .notEqual, .unquoted("red"))
            ),
            .basic(.keyValue("color", .notEqual, "red"))
        ),
        
        // MARK: - Incomplete comparisons
        TestCase(
            "foo:",
            PartialSearchFilter(
                negated: false,
                content: .filter("foo", .including, .unquoted(""))
            ),
            nil
        ),
        
        TestCase(
            "power!",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .incompleteNotEqual, .unquoted(""))
            ),
            nil
        ),
        
        TestCase(
            "power!value",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .incompleteNotEqual, .unquoted("value"))
            ),
            nil
        ),
        
        TestCase(
            "cmc<",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .lessThan, .unquoted(""))
            ),
            nil,
        ),
        
        TestCase(
            "power>",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThan, .unquoted(""))
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
            .basic(.regex("filtered", .including, "/regex with whitespace/"))
        ),
        
        TestCase(
            "name:/^lightning/",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.forwardSlash, "^lightning"))
            ),
            .basic(.regex("name", .including, "/^lightning/"))
        ),
        
        TestCase(
            "oracle:/draw.*card/",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.forwardSlash, "draw.*card"))
            ),
            .basic(.regex("oracle", .including, "/draw.*card/"))
        ),
        
        TestCase(
            "-name:/^chain/",
            PartialSearchFilter(
                negated: true,
                content: .filter("name", .including, .balanced(.forwardSlash, "^chain"))
            ),
            .negated(.regex("name", .including, "/^chain/"))
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
        
        TestCase(
            "name:/^lightning",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .unterminated(.forwardSlash, "^lightning"))
            ),
            nil
        ),
        
        TestCase(
            "oracle:/draw",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .unterminated(.forwardSlash, "draw"))
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
            "oracle:\"draw",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .unterminated(.doubleQuote, "draw"))
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
                content: .name(false, .unquoted(""))
            ),
            .basic(.name("", false))
        ),
        
        TestCase(
            "-",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .unquoted(""))
            ),
            .negated(.name("", false))
        ),
        
        TestCase(
            "!",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .unquoted(""))
            ),
            .basic(.name("", true))
        ),
        
        TestCase(
            "type:",
            PartialSearchFilter(
                negated: false,
                content: .filter("type", .including, .unquoted(""))
            ),
            nil,
        ),
        
        // MARK: - Mixed case field names
        TestCase(
            "Type:creature",
            PartialSearchFilter(
                negated: false,
                content: .filter("Type", .including, .unquoted("creature"))
            ),
            .basic(.keyValue("Type", .including, "creature"))
        ),
        
        TestCase(
            "POWER>3",
            PartialSearchFilter(
                negated: false,
                content: .filter("POWER", .greaterThan, .unquoted("3"))
            ),
            .basic(.keyValue("POWER", .greaterThan, "3"))
        ),
        
        // MARK: - Complex quoted strings
        TestCase(
            "oracle:\"destroy target creature\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "destroy target creature"))
            ),
            .basic(.keyValue("oracle", .including, "destroy target creature"))
        ),
        
        TestCase(
            "name:\"Lightning Bolt\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.doubleQuote, "Lightning Bolt"))
            ),
            .basic(.keyValue("name", .including, "Lightning Bolt"))
        ),
        
        // MARK: - Edge cases with special characters
        TestCase(
            "name:\"test:value\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.doubleQuote, "test:value"))
            ),
            .basic(.keyValue("name", .including, "test:value"))
        ),
        
        TestCase(
            "oracle:\">3\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, ">3"))
            ),
            .basic(.keyValue("oracle", .including, ">3"))
        ),
        
        // MARK: - Regex with comparison operators
        TestCase(
            "name=/^L/",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .equal, .balanced(.forwardSlash, "^L"))
            ),
            .basic(.regex("name", .equal, "/^L/"))
        ),
        
        TestCase(
            "power>/3/",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThan, .balanced(.forwardSlash, "3"))
            ),
            .basic(.regex("power", .greaterThan, "/3/"))
        ),
        
        // MARK: - Single character inputs
        TestCase(
            "a",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unquoted("a"))
            ),
            .basic(.name("a", false))
        ),
        
        TestCase(
            "-a",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .unquoted("a"))
            ),
            .negated(.name("a", false))
        ),
        
        // MARK: - Numbers and special characters in values
        TestCase(
            "cmc:3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .including, .unquoted("3"))
            ),
            .basic(.keyValue("cmc", .including, "3"))
        ),
        
        TestCase(
            "loyalty:\"5\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("loyalty", .including, .balanced(.doubleQuote, "5"))
            ),
            .basic(.keyValue("loyalty", .including, "5"))
        ),
        
        // MARK: - Multiple operators in sequence
        TestCase(
            "field:=value",
            PartialSearchFilter(
                negated: false,
                content: .filter("field", .including, .unquoted("=value"))
            ),
            .basic(.keyValue("field", .including, "=value"))
        ),
        
        // MARK: - Spaces in unquoted values (edge case)
        TestCase(
            "oracle:draw a card",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .unquoted("draw a card"))
            ),
            .basic(.keyValue("oracle", .including, "draw a card"))
        ),
        
        // MARK: - Negation with all comparison types
        TestCase(
            "-power>=5",
            PartialSearchFilter(
                negated: true,
                content: .filter("power", .greaterThanOrEqual, .unquoted("5"))
            ),
            .negated(.keyValue("power", .greaterThanOrEqual, "5"))
        ),
        
        TestCase(
            "-cmc<=2",
            PartialSearchFilter(
                negated: true,
                content: .filter("cmc", .lessThanOrEqual, .unquoted("2"))
            ),
            .negated(.keyValue("cmc", .lessThanOrEqual, "2"))
        ),
        
        TestCase(
            "-color=blue",
            PartialSearchFilter(
                negated: true,
                content: .filter("color", .equal, .unquoted("blue"))
            ),
            .negated(.keyValue("color", .equal, "blue"))
        ),
        
        TestCase(
            "-type!=land",
            PartialSearchFilter(
                negated: true,
                content: .filter("type", .notEqual, .unquoted("land"))
            ),
            .negated(.keyValue("type", .notEqual, "land"))
        ),
        
        // MARK: - Empty quotes
        TestCase(
            "\"\"",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.doubleQuote, ""))
            ),
            .basic(.name("", false))
        ),
        
        TestCase(
            "''",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, ""))
            ),
            .basic(.name("", false))
        ),
        
        // Empty strings are permitted if they are explicitly quoted. Just for UX clarity when you
        // type one in, not because it means anything useful.
        TestCase(
            "oracle:\"\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, ""))
            ),
            .basic(.keyValue("oracle", .including, "")),
        ),
        
        TestCase(
            "name://",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.forwardSlash, ""))
            ),
            .basic(.regex("name", .including, "//"))
        ),
        
        TestCase(
            "/regexwithoutfilter/",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.forwardSlash, "regexwithoutfilter")),
            ),
            .basic(.name("/regexwithoutfilter/", false)),
        ),
        
        TestCase(
            "/^test$/",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.forwardSlash, "^test$")),
            ),
            .basic(.name("/^test$/", false)),
        ),
        
        TestCase(
            "type: creature",
            PartialSearchFilter(
                negated: false,
                content: .filter("foo", .including, .unquoted(" bar")),
            ),
            .basic(.keyValue("foo", .including, " bar")),
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
