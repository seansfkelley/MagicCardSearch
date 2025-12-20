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

internal func parseVerbatim(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .Verbatim)
}

internal func parseOr(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .Or)
}

internal func parseWhitespace(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .Whitespace)
}

func parseParenthesizedQuery(_ input: String) throws -> ParenthesizedQuery {
    let lexer = CitronLexer<LexedParenthesizedQueryToken>(rules: [
        .regexPattern(#"'[^']*('|$)"#, parseVerbatim), // highest priority
        .regexPattern(#""[^"]*("|$)"#, parseVerbatim), // highest priority
        .regexPattern(#"/[^/]*(/|$)"#, parseVerbatim), // highest priority
        .regexPattern(#"(?! )or(?! )"#, parseOr),
        .string("(", ("(", .OpenParen)),
        .string(")", (")", .CloseParen)),
        .regexPattern(#"[ \n\t]+"#, parseWhitespace),
        .regexPattern(#"."#, parseVerbatim),
    ])
    
    // TODO:
    //   1. trim whitespace from input and preserve it
    //   2. lex into an intermediate type without ranges (just String!)
    //   3. change lexing rules to include whitespace around parens and ORs
    //   4. add a verbatim rule that starts with at least non-paren and continues until it hits
    //      whitespace or a balanced character or a close paren
    //   5. keep the whitespace rule, for when it's not next to an operator
    //   6. post-process the lexed tokens to:
    //      - add ranges
    //      - coalesce adjacent Verbatims -- this is just a lexing convenience so I don't have to
    //        write insane regexes, but I could also write insane regexes instead
    //      - replace any whitespace with a synthetic AND token set to the whitespace's range
    //        - this should be _all_ whitespace, since that that isn't assigned to a paren or an OR
    //          is necessarily going to function as AND
    //    7. run the tokens with the ranges through the parser
    
    // alternate idea: if whitespace not adjacent to operators is unambiguously an AND, why not:
    //   - write those insane regexes to capture all filter-like things as single tokens
    //   - make the parens and ORs take as much whitespace as possible
    //   - treat all remaining whitespace as AND
    //
    // we'd still have to post-process the tokens to inject the ranges, but only that. and also trim
    // whitespace at the start and preserve it, to avoid having to deal with whitespace that could
    // potentially be neither an AND nor part of an operator.
    
    // also, uh oh, I forgot about negation
    
    // when this parser exists, we can find all filters, including those in progress, with the
    // following algorithm:
    //
    // 1. try to parse the string, if yes, done
    // 2. otherwise, count the number of open parenthesis (naively, excluding quoting and such)
    // 3. append a dummy " nonfilter" to the search term
    // 4. for each count of open parenthesis, append a close parenthesis, and then try to parse it
    // 5. if it still doesn't ever parse, give up
    //
    // or just write a grammar that knows how to parse incomplete input. it's a simple enough language.
    //
    // this algorithm fails if the last term that's incomplete has unterminated quotes. how to detect
    // those and try to close them? could permit parsing them as a literal if and only if they
    // continue to the end of the input entirely.
    
    var tokens: [(ParenthesizedQueryTokenContent, ParenthesizedQueryParser.CitronTokenCode)] = []
    try lexer.tokenize(input) { token, code in
        if code == .Verbatim, let previous = tokens.last, previous.1 == .Verbatim {
            _ = tokens.popLast()
            tokens.append((
                .init(
                    content: "\(previous.0.content)\(token)",
                    range: previous.0.range.lowerBound..<input.index(previous.0.range.upperBound, offsetBy: token.count),
                ),
                .Verbatim,
            ))
        } else if code == .Verbatim && tokens.count >= 2 && tokens[tokens.count - 2].1 == .Verbatim && tokens[tokens.count - 1].1 == .Whitespace {
            
        } else {
            tokens.append((
                .init(content: token, range: input.startIndex..<token.endIndex),
                code,
            ))
        }
    }
    
    let parser = ParenthesizedQueryParser()
    var lastToken: LexedParenthesizedQueryToken
    try lexer.tokenize(input) { token, code in
        if let last = lastToken, last.1 == .Verbatim && code == .Verbatim {
            lastToken = (
                .init(
                    content: "\(last.0.content)\(token.content)",
                    range: last.0.range.lowerBound..<token.range.upperBound,
                ),
                .Verbatim,
            )
        } else {
            lastToken = token
            try parser.consume(token: lastToken, code: code)
        }
    }
    return try parser.endParsing()
}
