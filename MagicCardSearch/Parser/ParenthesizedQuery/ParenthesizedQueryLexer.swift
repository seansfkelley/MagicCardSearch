//
//  SearchFilterLexer.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//
struct ParenthesizedQueryTokenContent {
    let content: String
    var range: Range<String.Index>
}

internal typealias LexedParenthesizedQueryToken = (
    String, ParenthesizedQueryParser.CitronTokenCode
)

internal func parseOpenParen(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .OpenParen)
}

internal func parseCloseParen(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .CloseParen)
}

internal func parseOr(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .Or)
}

internal func parseVerbatim(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .Verbatim)
}

internal func parseWhitespace(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .And)
}

func parseParenthesizedQuery(_ input: String) throws -> ParenthesizedQuery {
    let trimmedInput = String(input.trimmingPrefix(/\s+/))
    
    let lexer = CitronLexer<LexedParenthesizedQueryToken>(rules: [
        .regexPattern(#"\s*-?(\s*"#, parseOpenParen),
        .regexPattern(#"\s*)\s*"#, parseOpenParen),
        .regexPattern(#"\s+or\s+"#, parseOr),
        // In principle we could have a single regex matching Verbatim things, but it would be
        // horrible and wildly unreadable. Instead, we separate the balanced-characters parts into
        // their own and define a non-whitespace-permitting rule for everything else, then
        // post-process the tokens to coalesce adjacent ones.
        .regexPattern(#"[^'"/ \n\t]+"#, parseVerbatim),
        .regexPattern(#"'[^']*('|$)"#, parseVerbatim),
        .regexPattern(#""[^"]*("|$)"#, parseVerbatim),
        .regexPattern(#"/[^/]*(/|$)"#, parseVerbatim),
        .regexPattern(#"[ \n\t]+"#, parseWhitespace),
    ])
    
    var tokens: [(ParenthesizedQueryTokenContent, ParenthesizedQueryParser.CitronTokenCode)] = []
    try lexer.tokenize(trimmedInput) { token, code in
        if tokens.isEmpty {
            tokens.append((
                .init(content: token, range: trimmedInput.startIndex..<trimmedInput.index(trimmedInput.startIndex, offsetBy: token.count)),
                code,
            ))
        } else if code == .Verbatim, let previous = tokens.last, previous.1 == .Verbatim {
            tokens.removeLast()
            let previousStart = previous.0.range.lowerBound
            let previousEnd = previous.0.range.upperBound
            tokens.append((
                .init(
                    content: "\(previous.0.content)\(token)",
                    range: previousStart..<trimmedInput.index(previousEnd, offsetBy: token.count),
                ),
                .Verbatim,
            ))
        } else {
            let previousEnd = tokens.last!.0.range.upperBound
            tokens.append((
                .init(content: token, range: previousEnd..<trimmedInput.index(previousEnd, offsetBy: token.count)),
                code,
            ))
        }
    }
    
    let parser = ParenthesizedQueryParser()
    for (token, code) in tokens {
        try parser.consume(token: token, code: code)
    }
    return try parser.endParsing()
}
