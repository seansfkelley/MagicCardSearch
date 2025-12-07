internal enum Token {
    case void
    case term(String)
}

func doubleQuoteIfNecessary(_ string: String) -> String {
    return string.contains(" ") ? "\"\(string)\"" : string
}

/// Quoting to preserve whitespace not required; any quotes present will be assumed to be part of the term to search for.
enum SearchFilter: Equatable, Codable {
    case name(String)
    case keyValue(String, Comparison, String)

    static func tryParseKeyValue(_ input: String) -> SearchFilter? {
        return try? parse(input)
    }
    
    var idiomaticString: String {
        return switch self {
        case .name(let n): n
        case .keyValue(let key, let comparison, let value): "\(key)\(comparison.symbol)\(doubleQuoteIfNecessary(value))"
        }
    }

    func toScryfallQueryString() -> String {
        // TODO: Is this all the right syntax? Does name need a `name:`; do we need to quote?
        return switch self {
        case .name(let n): n
        case .keyValue(let key, let comparison, let value): "\(key)\(comparison.symbol)\(value)"
        }
    }
}

enum Comparison: String, Codable {
    case including = ":"
    case equal = "="
    case notEqual = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="

    var symbol: String {
        return self.rawValue
    }
}

typealias LexedTokenData = (
    MagicCardSearchGrammar.CitronToken, MagicCardSearchGrammar.CitronTokenCode
)

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
    .regexPattern("\\s+", parseWhitespace),
])

private func parse(_ input: String) throws -> SearchFilter {
    let parser = MagicCardSearchGrammar()
    try lexer.tokenize(input) { (t, c) in
        try parser.consume(token: t, code: c)
    }
    return try parser.endParsing()
}
