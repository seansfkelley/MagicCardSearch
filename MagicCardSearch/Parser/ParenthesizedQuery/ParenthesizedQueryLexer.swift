//
//  SearchFilterLexer.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-19.
//
typealias ParenthesizedQueryTokenContent = Range<String.Index>

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

internal func parseImpliedAnd(_ input: String) -> LexedParenthesizedQueryToken? {
    return (input, .And)
}

func parseParenthesizedQuery(_ input: String) throws -> ParenthesizedQuery {
    // TODO: Offset the ranges based on how much was removed here.
    let trimmedInput = input.trimmingCharacters(in: .whitespaces)
    
    let lexer = CitronLexer<LexedParenthesizedQueryToken>(rules: [
        .regexPattern(#"-?\(\s*"#, parseOpenParen),
        .regexPattern(#"\s*\)"#, parseCloseParen),
        .regexPattern(#"(\b|\s+)or(\s+|\b)"#, parseOr),
        // In principle we could have a single regex matching Verbatim things, but it would be
        // horrible and wildly unreadable. Instead, we separate the balanced-characters parts into
        // their own and define a non-whitespace-permitting rule for everything else, then
        // post-process the tokens to coalesce adjacent ones.
        .regexPattern(#"[^'"/ \n\t\)]+"#, parseVerbatim),
        .regexPattern(#"'[^']*('|$)"#, parseVerbatim),
        .regexPattern(#""[^"]*("|$)"#, parseVerbatim),
        .regexPattern(#"/[^/]*(/|$)"#, parseVerbatim),
        .regexPattern(#"[ \n\t]+"#, parseImpliedAnd),
    ])
    
    var tokens: [(ParenthesizedQueryTokenContent, ParenthesizedQueryParser.CitronTokenCode)] = []
    try lexer.tokenize(trimmedInput) { token, code in
        if tokens.isEmpty {
            tokens.append((
                trimmedInput.startIndex..<trimmedInput.index(trimmedInput.startIndex, offsetBy: token.count),
                code,
            ))
        } else if code == .Verbatim, let previous = tokens.last, previous.1 == .Verbatim {
            tokens.removeLast()
            let previousStart = previous.0.lowerBound
            let previousEnd = previous.0.upperBound
            tokens.append((
                previousStart..<trimmedInput.index(previousEnd, offsetBy: token.count),
                .Verbatim,
            ))
        } else {
            let previousEnd = tokens.last!.0.upperBound
            tokens.append((
                previousEnd..<trimmedInput.index(previousEnd, offsetBy: token.count),
                code,
            ))
        }
    }
    
    let errorCapturer = ParenthesizedQueryErrorDelegate()
    
    let parser = ParenthesizedQueryParser()
    parser.isTracingEnabled = true
    parser.errorCaptureDelegate = errorCapturer
    
    for (token, code) in tokens {
        try parser.consume(token: token, code: code)
    }
    do {
        return try parser.endParsing()
    } catch {
        print(error)
        throw error
    }
}

class ParenthesizedQueryErrorDelegate: ParenthesizedQueryParser.CitronErrorCaptureDelegate {
//    func shouldSaveErrorForCapturing(error: any Error) -> Bool {
//        <#code#>
//    }

    func shouldCaptureErrorOnQuery(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedQuery> {
        collectAllRanges(in: state)
    }
    
    func shouldCaptureErrorOnParenthesized(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedQuery> {
        collectAllRanges(in: state)
    }
    
    private func collectAllRanges(in state: ParenthesizedQueryParser.CitronErrorCaptureState) -> CitronErrorCaptureResponse<ParenthesizedQuery> {
        var ranges: [Range<String.Index>] = []
        for resolvedSymbol in state.resolvedSymbols {
            if let query = resolvedSymbol.value as? ParenthesizedQuery {
                ranges.append(contentsOf: query.filters)
            }
        }
        return .captureAs(.init(filters: ranges))
    }
}
