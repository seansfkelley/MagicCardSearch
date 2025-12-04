internal enum Token {
    case void
    case text(String)
}

enum SearchFilter {
    case name(String)
    case set(StringComparison, String)
    case manaValue(Comparison, String)
    case color(Comparison, [String])
    case format(StringComparison, String)
}

enum StringComparison {
    case equal
    case notEqual
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

internal func parseText(_ input: String) -> LexedTokenData? {
    return (.text(input), .Text)
}

private let lexer = CitronLexer<LexedTokenData>(rules: [
    .string("set", (.void, .Set)),
    .string("s", (.void, .Set)),
    .string("manavalue", (.void, .ManaValue)),
    .string("mv", (.void, .ManaValue)),
    .string(":", (.void, .Equal)),
    .string("=", (.void, .Equal)),
    .string("!=", (.void, .NotEqual)),
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
