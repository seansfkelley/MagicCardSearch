//
//  SearchFilterLexer.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//
internal typealias SearchFilterTokenContent = String

internal typealias LexedSearchFilterToken = (
    SearchFilterParser.CitronToken, SearchFilterParser.CitronTokenCode
)

internal func parseQuoted(_ input: String) -> LexedSearchFilterToken? {
    // Assumes exactly 1 set of quotes on each side.
    return (
        String(input[input.index(after: input.startIndex)..<input.index(before: input.endIndex)]),
        .QuotedLiteral
    )
}

internal func parseRegex(_ input: String) -> LexedSearchFilterToken? {
    return (input, .Regex)
}

internal func parseParenthesized(_ input: String) -> LexedSearchFilterToken? {
    return (input, .Parenthesized)
}

internal func parseAlphanumeric(_ input: String) -> LexedSearchFilterToken? {
    return (input, .Alphanumeric)
}

internal func parseComparison(_ input: String) -> LexedSearchFilterToken? {
    return (input, .Comparison)
}

internal func parseSingleNonPairing(_ input: String) -> LexedSearchFilterToken? {
    return (input, .SingleNonPairing)
}

internal func parseUnclosedPairing(_ input: String) -> LexedSearchFilterToken? {
    return (input, .UnclosedPairing)
}

func parseSearchFilter(_ input: String) throws -> SearchFilter {
    let lexer = CitronLexer<LexedSearchFilterToken>(rules: [
        .regexPattern(#"'[^']*'"#, parseQuoted), // highest priority
        .regexPattern(#""[^"]*""#, parseQuoted), // highest priority
        .regexPattern(#"/[^/]*/"#, parseRegex), // highest priority
        .regexPattern(#"\([^\)]*\)"#, parseParenthesized), // highest priority
        .regexPattern(#"[a-zA-Z0-9]+"#, parseAlphanumeric),
        .string("-", ("-", .Minus)),
        .regexPattern(#"<=|<|>=|>|!=|=|:"#, parseComparison),
        .string("!", ("!", .Bang)), // must come after operators!
        .regexPattern(#"[^'"/ \t\n\(\)]"#, parseSingleNonPairing), // TODO: Can do a class of whitespace better than this?
        .regexPattern(#"['"/\(\)]"#, parseUnclosedPairing),
    ])
    
    let parser = SearchFilterParser()
    try lexer.tokenize(input) { token, code in
        try parser.consume(token: token, code: code)
    }
    return try parser.endParsing()
}
