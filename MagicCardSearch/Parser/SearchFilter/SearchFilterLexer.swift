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

func lexSearchFilter(_ input: String) throws -> [LexedSearchFilterToken] {
    let lexer = CitronLexer<LexedSearchFilterToken>(rules: [
        .regexPattern(#"'[^']*'"#, parseQuoted), // highest priority
        .regexPattern(#""[^"]*""#, parseQuoted), // highest priority
        .regexPattern(#"/[^/]*/"#) { ($0, .Regex) }, // highest priority
        .regexPattern(#"\([^\)]*\)"#) { ($0, .Parenthesized) }, // highest priority
        .regexPattern(#"[a-zA-Z0-9]+"#) { ($0, .Alphanumeric) },
        .string("-", ("-", .Minus)),
        .regexPattern(#"<=|<|>=|>|!=|=|:"#) { ($0, .Comparison) },
        .string("!", ("!", .Bang)), // must come after operators!
        .regexPattern(#"[^'"/ \t\n\(\)]"#) { ($0, .SingleNonPairing) }, // TODO: Can do a class of whitespace better than this?
        .regexPattern(#"['"/\(\)]"#) { ($0, .UnclosedPairing) },
    ])
    
    var tokens: [LexedSearchFilterToken] = []
    try lexer.tokenize(input) { tokens.append($0) }
    return tokens
}
