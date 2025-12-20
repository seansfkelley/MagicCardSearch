//
//  SearchFilterLexer.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//
internal typealias SearchFilterGrammarToken = String

internal typealias LexedTokenData = (
    SearchFilterParser.CitronToken, SearchFilterParser.CitronTokenCode
)

internal func parseQuoted(_ input: String) -> LexedTokenData? {
    // Assumes exactly 1 set of quotes on each side.
    return (
        String(input[input.index(after: input.startIndex)..<input.index(before: input.endIndex)]),
        .QuotedLiteral
    )
}

internal func parseRegex(_ input: String) -> LexedTokenData? {
    return (input, .Regex)
}

internal func parseParenthesized(_ input: String) -> LexedTokenData? {
    return (input, .Parenthesized)
}

internal func parseAlphanumeric(_ input: String) -> LexedTokenData? {
    return (input, .Alphanumeric)
}

internal func parseComparison(_ input: String) -> LexedTokenData? {
    return (input, .Comparison)
}

internal func parseSingleNonPairing(_ input: String) -> LexedTokenData? {
    return (input, .SingleNonPairing)
}

internal func parseUnclosedPairing(_ input: String) -> LexedTokenData? {
    return (input, .UnclosedPairing)
}

func parseSearchFilter(_ input: String) throws -> SearchFilter {
    let lexer = CitronLexer<LexedTokenData>(rules: [
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
