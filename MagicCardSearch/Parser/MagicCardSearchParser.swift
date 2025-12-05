internal enum Token {
    case void
    case term(String)
}

struct SearchFilter {
    let key: String
    let comparison: Comparison
    let value: String
    
    init(_ key: String, _ comparison: Comparison, _ value: String) {
        self.key = key
        self.comparison = comparison
        self.value = value
    }
    
    static func from(_ input: String) -> SearchFilter {
        if let result = try? parse(input) {
            return result
        } else {
            return SearchFilter("name", .equal, input)
        }
    }
}

enum Comparison {
    case equal
    case notEqual
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual
}

typealias LexedTokenData = (MagicCardSearchGrammar.CitronToken, MagicCardSearchGrammar.CitronTokenCode)

internal func parseTerm(_ input: String) -> LexedTokenData? {
    return (.term(input), .Term)
}

private let lexer = CitronLexer<LexedTokenData>(rules: [
    .string(":", (.void, .Equal)),
    .string("=", (.void, .Equal)),
    .string("!=", (.void, .NotEqual)),
    .string("<", (.void, .LessThan)),
    .string("<=", (.void, .LessThanOrEqual)),
    .string(">", (.void, .GreaterThan)),
    .string(">=", (.void, .GreaterThanOrEqual)),
    .string("'", (.void, .SingleQuote)),
    .string("\"", (.void, .DoubleQuote)),
    .regexPattern("[^'\" ]", parseTerm),
])

private func parse(_ input: String) throws -> SearchFilter {
    let parser = MagicCardSearchGrammar()
    try lexer.tokenize(input) { (t, c) in
        try parser.consume(token: t, code: c)
    }
    return try parser.endParsing()
}
