internal enum Token {
    case void
    case text(String)
}

enum FilterKind {
    case name
    case set
    case manaValue
}

enum Comparison {
    case nameContains
    case colon // is this synonymous with colon?
    case equal
    case lessThan
    case lessThanOrEqual
    case greaterThan
    case greaterThanOrEqual
}

struct SearchFilter: Equatable {
    let kind: FilterKind
    let comparison: Comparison
    let value: String
    
    static func from(_ input: String) -> SearchFilter? {
        return try? parse(input)
    }
    
    init(_ kind: FilterKind, _ comparison: Comparison, _ value: String) {
        self.kind = kind
        self.comparison = comparison
        self.value = value
    }
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
