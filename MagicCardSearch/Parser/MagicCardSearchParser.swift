internal enum Token {
    case void
    case term(String)
}

struct SearchFilter: Equatable {
    let key: String
    let comparison: Comparison
    let value: String
    
    init(_ key: String, _ comparison: Comparison, _ value: String) {
        self.key = key
        self.comparison = comparison
        self.value = value
    }
    
    static func from(_ input: String) -> SearchFilter? {
        return try? parse(input)
    }
    
    func toScryfallString() -> String {
        let needsQuotes = value.contains(" ")
        let quotedValue = needsQuotes ? "\"\(value)\"" : value
        return "\(key)\(comparison.symbol)\(quotedValue)"
    }
}

enum Comparison {
    case including
    case equal
    case notEqual
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual
    
    var symbol: String {
        return switch self {
        case .including: ":"
        case .equal: "="
        case .notEqual: "!="
        case .lessThan: "<"
        case .lessThanOrEqual: "<="
        case .greaterThan: ">"
        case .greaterThanOrEqual: ">="
        }
    }
}

typealias LexedTokenData = (MagicCardSearchGrammar.CitronToken, MagicCardSearchGrammar.CitronTokenCode)

internal func parseTerm(_ input: String) -> LexedTokenData? {
    return (.term(input), .Term)
}

internal func parseWhitespace(_ input: String) -> LexedTokenData? {
    return (.void, .Whitespace)
}

private let lexer = CitronLexer<LexedTokenData>(rules: [
    .string(":", (.void, .Including)),
    .string("!=", (.void, .NotEqual)),
    .string("<=", (.void, .LessThanOrEqual)),
    .string("<", (.void, .LessThan)),
    .string(">=", (.void, .GreaterThanOrEqual)),
    .string(">", (.void, .GreaterThan)),
    .string("=", (.void, .Equal)),
    .string("'", (.void, .SingleQuote)),
    .string("\"", (.void, .DoubleQuote)),
    .regexPattern("[^'\" =><!:]+", parseTerm),
    .regexPattern("\\s+", parseWhitespace)
])

private func parse(_ input: String) throws -> SearchFilter {
    let parser = MagicCardSearchGrammar()
    try lexer.tokenize(input) { (t, c) in
        try parser.consume(token: t, code: c)
    }
    return try parser.endParsing()
}
