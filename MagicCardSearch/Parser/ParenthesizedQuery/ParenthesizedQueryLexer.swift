//
//  SearchFilterLexer.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//
struct ParenthesizedQueryTokenContent {
    let content: String
    var range: Range<String.Index>?
}

internal typealias LexedParenthesizedQueryToken = (
    ParenthesizedQueryParser.CitronToken, ParenthesizedQueryParser.CitronTokenCode
)

internal func parseVerbatim(_ input: String) -> LexedParenthesizedQueryToken? {
    return (.init(content: input), .Verbatim)
}

internal func parseOr(_ input: String) -> LexedParenthesizedQueryToken? {
    return (.init(content: input), .Or)
}

internal func parseWhitespace(_ input: String) -> LexedParenthesizedQueryToken? {
    return (.init(content: input), .Whitespace)
}

func parseParenthesizedQuery(_ input: String) throws -> ParenthesizedQuery {
    let lexer = CitronLexer<LexedParenthesizedQueryToken>(rules: [
        .regexPattern(#"'[^']*('|$)"#, parseVerbatim), // highest priority
        .regexPattern(#""[^"]*("|$)"#, parseVerbatim), // highest priority
        .regexPattern(#"/[^/]*(/|$)"#, parseVerbatim), // highest priority
        .regexPattern(#"(?! )or(?! )"#, parseOr),
        .string("(", (.init(content: "("), .OpenParen)),
        .string(")", (.init(content: ")"), .CloseParen)),
        .regexPattern(#"[ \n\t]+"#, parseWhitespace),
        .regexPattern(#"."#, parseVerbatim),
    ])
    
    let parser = ParenthesizedQueryParser()
    try lexer.tokenize(input) { token, code in
        try parser.consume(token: token, code: code)
    }
    return try parser.endParsing()
}
