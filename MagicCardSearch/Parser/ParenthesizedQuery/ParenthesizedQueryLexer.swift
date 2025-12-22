//
//  SearchFilterLexer.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//
struct ParenthesizedQueryTokenContent {
    let content: String
    let range: Range<String.Index>
    
    init(_ content: String, _ range: Range<String.Index>) {
        self.content = content
        self.range = range
    }
}

internal typealias LexedParenthesizedQueryToken = (
    ParenthesizedQueryParser.CitronToken, ParenthesizedQueryParser.CitronTokenCode
)

func lexParenthesizedQuery(_ input: String) throws -> [LexedParenthesizedQueryToken] {
    guard !input.isEmpty else {
        return []
    }
    
    let lexer = CitronLexer<(String, ParenthesizedQueryParser.CitronTokenCode)>(rules: [
        .regexPattern(#"-?\(\s*"#) { ($0, .OpenParen) },
        .regexPattern(#"\s*\)"#) { ($0, .CloseParen) },
        .regexPattern(#"(\b|\s+)or(\s+|\b)"#) { ($0, .Or) },
        // In principle we could have a single regex matching Verbatim things, but it would be
        // horrible and wildly unreadable. Instead, we separate the balanced-characters parts into
        // their own and define a non-whitespace-permitting rule for everything else, then
        // post-process the tokens to coalesce adjacent ones.
        .regexPattern(#"[^'"/ \n\t\)]+"#) { ($0, .Verbatim) },
        .regexPattern(#"'[^']*('|$)"#) { ($0, .Verbatim) },
        .regexPattern(#""[^"]*("|$)"#) { ($0, .Verbatim) },
        .regexPattern(#"/[^/]*(/|$)"#) { ($0, .Verbatim) },
        .regexPattern(#"[ \n\t]+"#) { ($0, .And) },
    ])
    
    var tokens: [LexedParenthesizedQueryToken] = []
    try lexer.tokenize(input) { token, code in
        if tokens.isEmpty {
            tokens.append((
                ParenthesizedQueryTokenContent(
                    token,
                    input.startIndex..<input.index(input.startIndex, offsetBy: token.count),
                ),
                code,
            ))
        } else if code == .Verbatim, let previous = tokens.last, previous.1 == .Verbatim {
            tokens.removeLast()
            let previousStart = previous.0.range.lowerBound
            let previousEnd = previous.0.range.upperBound
            tokens.append((
                ParenthesizedQueryTokenContent(
                    token,
                    previousStart..<input.index(previousEnd, offsetBy: token.count),
                ),
                .Verbatim,
            ))
        } else {
            let previousEnd = tokens.last!.0.range.upperBound
            tokens.append((
                ParenthesizedQueryTokenContent(
                    token,
                    previousEnd..<input.index(previousEnd, offsetBy: token.count),
                ),
                code,
            ))
        }
    }
    return tokens
}
