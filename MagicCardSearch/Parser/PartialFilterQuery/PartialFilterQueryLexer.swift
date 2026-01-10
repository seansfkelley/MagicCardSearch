public struct PolarityString: FilterQueryLeaf {
    let polarity: Polarity
    let string: String
    
    init(_ polarity: Polarity, _ string: String) {
        self.polarity = polarity
        self.string = string
    }
    
    public var description: String { "\(polarity.description)\(string)" }
    public var negated: PolarityString { .init(polarity.negated, string) }
}

public typealias PartialFilterQuery = FilterQuery<PolarityString>

struct PartialFilterQueryTokenContent {
    let content: String
    let range: Range<String.Index>
    
    init(_ content: String, _ range: Range<String.Index>) {
        self.content = content
        self.range = range
    }
}

internal typealias LexedPartialFilterQueryToken = (
    PartialFilterQueryParser.CitronToken, PartialFilterQueryParser.CitronTokenCode
)

// swiftlint:disable:next function_body_length
func lexPartialFilterQuery(_ input: String, allowingUnterminatedLiterals: Bool = false) throws -> [LexedPartialFilterQueryToken] {
    guard !input.isEmpty else {
        return []
    }
    
    var rules: [CitronLexer<(String, PartialFilterQueryParser.CitronTokenCode)>.LexingRule] = [
        .regexPattern(#"-?\(\s*"#) { ($0, .OpenParen) },
        .regexPattern(#"\s*\)"#) { ($0, .CloseParen) },
        .regexPattern(#"(\b|\s+)or(\s+|\b)"#) { ($0, .Or) },
        // In principle we could have a single regex matching Verbatim things, but it would be
        // horrible and wildly unreadable. Instead, we separate the balanced-characters parts into
        // their own and define a non-whitespace-permitting rule for everything else, then
        // post-process the tokens to coalesce adjacent ones.
        .regexPattern(#"[^'"/ \n\t\)]+"#) { ($0, .Verbatim) },
    ]
    
    if allowingUnterminatedLiterals {
        rules.append(contentsOf: [
            .regexPattern(#"'[^']*('|$)"#) { ($0, .Verbatim) },
            .regexPattern(#""[^"]*("|$)"#) { ($0, .Verbatim) },
            .regexPattern(#"/[^/]*(/|$)"#) { ($0, .Verbatim) },
        ])
    } else {
        rules.append(contentsOf: [
            .regexPattern(#"'[^']*'"#) { ($0, .Verbatim) },
            .regexPattern(#""[^"]*""#) { ($0, .Verbatim) },
            .regexPattern(#"/[^/]*/"#) { ($0, .Verbatim) },
        ])
    }
    
    rules.append(.regexPattern(#"[ \n\t]+"#) { ($0, .And) })
    
    let lexer = CitronLexer<(String, PartialFilterQueryParser.CitronTokenCode)>(rules: rules)
    
    var tokens: [LexedPartialFilterQueryToken] = []
    try lexer.tokenize(input) { token, code in
        if tokens.isEmpty {
            tokens.append((
                .init(
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
                .init(
                    "\(previous.0.content)\(token)",
                    previousStart..<input.index(previousEnd, offsetBy: token.count),
                ),
                .Verbatim,
            ))
        } else {
            let previousEnd = tokens.last!.0.range.upperBound
            tokens.append((
                .init(
                    token,
                    previousEnd..<input.index(previousEnd, offsetBy: token.count),
                ),
                code,
            ))
        }
    }

    // Removing whitespace here _kind of_ redefines the language to be whitespace-insensitive, even
    // though we consider some whitespace to be a token (namely, And). It's a bit weird. In any case
    // this is useful because some downstream processes like PlausibleFilterRanges do simultaneously
    // care about things that are not filters, but also positions in the input text.
    return tokens.map { untrimmedToken in
        var token = untrimmedToken

        if token.1 == .Or || token.1 == .OpenParen || token.1 == .CloseParen {
            if let match = token.0.content.firstMatch(of: /^\s+/) {
                token.0 = .init(
                    String(token.0.content.dropFirst(match.count)),
                    input.index(token.0.range.lowerBound, offsetBy: match.count)..<token.0.range.upperBound,
                )
            }

            if let match = token.0.content.firstMatch(of: /\s+$/) {
                token.0 = .init(
                    String(token.0.content.dropLast(match.count)),
                    token.0.range.lowerBound..<input.index(token.0.range.upperBound, offsetBy: -match.count),
                )
            }
        }

        return token
    }
}
