internal enum Token {
    case void
    case text(String)
}

struct SearchFilter {
    let kind: String
    let value: String
    
    init(_ kind: String, _ value: String) {
        self.kind = kind
        self.value = value
    }
}

typealias LexedTokenData = (MagicCardSearchGrammar.CitronToken, MagicCardSearchGrammar.CitronTokenCode)

internal func parseText(_ input: String) -> LexedTokenData? {
    return (.text(input), .Text)
}

private let lexer = CitronLexer<LexedTokenData>(rules: [
    .string(":", (.void, .Colon)),
    .string("=", (.void, .Equal)),
    .string("<", (.void, .LessThan)),
    .string("<=", (.void, .LessThanOrEqual)),
    .string(">", (.void, .GreaterThan)),
    .string(">=", (.void, .GreaterThanOrEqual)),
    .regexPattern("[^\"]+", parseText),
])

private func parse(_ input: String) throws -> SearchFilter {
    let parser = MagicCardSearchGrammar()
    try lexer.tokenize(input) { (t, c) in
        try parser.consume(token: t, code: c)
    }
    return try parser.endParsing()
}
