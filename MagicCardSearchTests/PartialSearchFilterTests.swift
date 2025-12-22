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
                content: .name(false, .unquoted("foo"))
            ),
            .init(.name("foo", false))
        ),
        
        TestCase(
            "teferi's",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unquoted("teferi's"))
            ),
            .init(.name("teferi's", false))
        ),
        
        TestCase(
            "{p}",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unquoted("{p}"))
            ),
            .init(.name("{p}", false))
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
            .init(.name("lightning bolt", false))
        ),
        
        // MARK: - Exact name searches (!)
        TestCase(
            "!Fire",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .unquoted("Fire"))
            ),
            .init(.name("Fire", true))
        ),
        
        TestCase(
            "!lightning",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .unquoted("lightning"))
            ),
            .init(.name("lightning", true))
        ),
        
        TestCase(
            "!\"Lightning Bolt\"",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .balanced(.doubleQuote, "Lightning Bolt"))
            ),
            .init(.name("Lightning Bolt", true))
        ),
        
        // MARK: - Quoted name searches
        TestCase(
            "'foo'",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, "foo"))
            ),
            .init(.name("foo", false))
        ),
        
        TestCase(
            "\"lightning bolt\"",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.doubleQuote, "lightning bolt"))
            ),
            .init(.name("lightning bolt", false))
        ),
        
        TestCase(
            "'lightning bolt'",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, "lightning bolt"))
            ),
            .init(.name("lightning bolt", false))
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
                content: .name(false, .unquoted("lightning"))
            ),
            .init(true, .name("lightning", false))
        ),
        
        TestCase(
            "-!lightning",
            PartialSearchFilter(
                negated: true,
                content: .name(true, .unquoted("lightning"))
            ),
            .init(true, .name("lightning", true))
        ),
        
        TestCase(
            "-\"lightning bolt\"",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .balanced(.doubleQuote, "lightning bolt"))
            ),
            .init(true, .name("lightning bolt", false))
        ),
        
        // MARK: - Key-value filters with ":"
        TestCase(
            "set:foo",
            PartialSearchFilter(
                negated: false,
                content: .filter("set", .including, .unquoted("foo"))
            ),
            .init(.keyValue("set", .including, "foo"))
        ),
        
        TestCase(
            "type:creature",
            PartialSearchFilter(
                negated: false,
                content: .filter("type", .including, .unquoted("creature"))
            ),
            .init(.keyValue("type", .including, "creature"))
        ),
        
        TestCase(
            "oracle:\"draw a card\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "draw a card"))
            ),
            .init(.keyValue("oracle", .including, "draw a card"))
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
                content: .filter("type", .including, .unquoted("creature"))
            ),
            .init(true, .keyValue("type", .including, "creature"))
        ),
        
        TestCase(
            "-oracle:\"draw a card\"",
            PartialSearchFilter(
                negated: true,
                content: .filter("oracle", .including, .balanced(.doubleQuote, "draw a card"))
            ),
            .init(true, .keyValue("oracle", .including, "draw a card"))
        ),
        
        // MARK: - Comparison operators
        TestCase(
            "s=bar",
            PartialSearchFilter(
                negated: false,
                content: .filter("s", .equal, .unquoted("bar"))
            ),
            .init(.keyValue("s", .equal, "bar"))
        ),
        
        TestCase(
            "mv>=bar",
            PartialSearchFilter(
                negated: false,
                content: .filter("mv", .greaterThanOrEqual, .unquoted("bar"))
            ),
            .init(.keyValue("mv", .greaterThanOrEqual, "bar"))
        ),
        
        TestCase(
            "m>{p/r}{g}",
            PartialSearchFilter(
                negated: false,
                content: .filter("m", .greaterThan, .unquoted("{p/r}{g}"))
            ),
            .init(.keyValue("m", .greaterThan, "{p/r}{g}"))
        ),
        
        TestCase(
            "power>3",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThan, .unquoted("3"))
            ),
            .init(.keyValue("power", .greaterThan, "3"))
        ),
        
        TestCase(
            "cmc<3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .lessThan, .unquoted("3"))
            ),
            .init(.keyValue("cmc", .lessThan, "3"))
        ),
        
        TestCase(
            "cmc<=3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .lessThanOrEqual, .unquoted("3"))
            ),
            .init(.keyValue("cmc", .lessThanOrEqual, "3"))
        ),
        
        TestCase(
            "color=red",
            PartialSearchFilter(
                negated: false,
                content: .filter("color", .equal, .unquoted("red"))
            ),
            .init(.keyValue("color", .equal, "red"))
        ),
        
        TestCase(
            "color!=red",
            PartialSearchFilter(
                negated: false,
                content: .filter("color", .notEqual, .unquoted("red"))
            ),
            .init(.keyValue("color", .notEqual, "red"))
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
            .init(.regex("filtered", .including, "/regex with whitespace/"))
        ),
        
        TestCase(
            "name:/^lightning/",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.forwardSlash, "^lightning"))
            ),
            .init(.regex("name", .including, "/^lightning/"))
        ),
        
        TestCase(
            "-name:/^chain/",
            PartialSearchFilter(
                negated: true,
                content: .filter("name", .including, .balanced(.forwardSlash, "^chain"))
            ),
            .init(true, .regex("name", .including, "/^chain/"))
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
                content: .name(false, .unquoted(""))
            ),
            .init(.name("", false))
        ),
        
        TestCase(
            "-",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .unquoted(""))
            ),
            .init(true, .name("", false))
        ),
        
        TestCase(
            "!",
            PartialSearchFilter(
                negated: false,
                content: .name(true, .unquoted(""))
            ),
            .init(.name("", true))
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
            .init(.keyValue("Type", .including, "creature"))
        ),
        
        TestCase(
            "POWER>3",
            PartialSearchFilter(
                negated: false,
                content: .filter("POWER", .greaterThan, .unquoted("3"))
            ),
            .init(.keyValue("POWER", .greaterThan, "3"))
        ),
        
        // MARK: - Edge cases with special characters
        TestCase(
            "name:\"test:value\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.doubleQuote, "test:value"))
            ),
            .init(.keyValue("name", .including, "test:value"))
        ),
        
        TestCase(
            "oracle:\">3\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, ">3"))
            ),
            .init(.keyValue("oracle", .including, ">3"))
        ),
        
        // MARK: - Regex with comparison operators
        TestCase(
            "name=/^L/",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .equal, .balanced(.forwardSlash, "^L"))
            ),
            .init(.regex("name", .equal, "/^L/"))
        ),
        
        TestCase(
            "power>/3/",
            PartialSearchFilter(
                negated: false,
                content: .filter("power", .greaterThan, .balanced(.forwardSlash, "3"))
            ),
            .init(.regex("power", .greaterThan, "/3/"))
        ),
        
        // MARK: - Single character inputs
        TestCase(
            "a",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .unquoted("a"))
            ),
            .init(.name("a", false))
        ),
        
        TestCase(
            "-a",
            PartialSearchFilter(
                negated: true,
                content: .name(false, .unquoted("a"))
            ),
            .init(true, .name("a", false))
        ),
        
        // MARK: - Numbers and special characters in values
        TestCase(
            "cmc:3",
            PartialSearchFilter(
                negated: false,
                content: .filter("cmc", .including, .unquoted("3"))
            ),
            .init(.keyValue("cmc", .including, "3"))
        ),
        
        TestCase(
            "loyalty:\"5\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("loyalty", .including, .balanced(.doubleQuote, "5"))
            ),
            .init(.keyValue("loyalty", .including, "5"))
        ),
        
        // MARK: - Multiple operators in sequence
        TestCase(
            "field:=value",
            PartialSearchFilter(
                negated: false,
                content: .filter("field", .including, .unquoted("=value"))
            ),
            .init(.keyValue("field", .including, "=value"))
        ),
        
        // MARK: - Spaces in unquoted values (edge case)
        TestCase(
            "oracle:draw a card",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .unquoted("draw a card"))
            ),
            .init(.keyValue("oracle", .including, "draw a card"))
        ),
        
        // MARK: - Negation with all comparison types
        TestCase(
            "-power>=5",
            PartialSearchFilter(
                negated: true,
                content: .filter("power", .greaterThanOrEqual, .unquoted("5"))
            ),
            .init(true, .keyValue("power", .greaterThanOrEqual, "5"))
        ),
        
        TestCase(
            "-cmc<=2",
            PartialSearchFilter(
                negated: true,
                content: .filter("cmc", .lessThanOrEqual, .unquoted("2"))
            ),
            .init(true, .keyValue("cmc", .lessThanOrEqual, "2"))
        ),
        
        TestCase(
            "-color=blue",
            PartialSearchFilter(
                negated: true,
                content: .filter("color", .equal, .unquoted("blue"))
            ),
            .init(true, .keyValue("color", .equal, "blue"))
        ),
        
        TestCase(
            "-type!=land",
            PartialSearchFilter(
                negated: true,
                content: .filter("type", .notEqual, .unquoted("land"))
            ),
            .init(true, .keyValue("type", .notEqual, "land"))
        ),
        
        // MARK: - Empty quotes
        TestCase(
            "\"\"",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.doubleQuote, ""))
            ),
            .init(.name("", false))
        ),
        
        TestCase(
            "''",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.singleQuote, ""))
            ),
            .init(.name("", false))
        ),
        
        // Empty strings are permitted if they are explicitly quoted. Just for UX clarity when you
        // type one in, not because it means anything useful.
        TestCase(
            "oracle:\"\"",
            PartialSearchFilter(
                negated: false,
                content: .filter("oracle", .including, .balanced(.doubleQuote, ""))
            ),
            .init(.keyValue("oracle", .including, "")),
        ),
        
        TestCase(
            "name://",
            PartialSearchFilter(
                negated: false,
                content: .filter("name", .including, .balanced(.forwardSlash, ""))
            ),
            .init(.regex("name", .including, "//"))
        ),
        
        TestCase(
            "/regexwithoutfilter/",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.forwardSlash, "regexwithoutfilter")),
            ),
            .init(.name("/regexwithoutfilter/", false)),
        ),
        
        TestCase(
            "/^test$/",
            PartialSearchFilter(
                negated: false,
                content: .name(false, .balanced(.forwardSlash, "^test$")),
            ),
            .init(.name("/^test$/", false)),
        ),
        
        TestCase(
            "type: creature",
            PartialSearchFilter(
                negated: false,
                content: .filter("type", .including, .unquoted(" creature")),
            ),
            .init(.keyValue("type", .including, " creature")),
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
