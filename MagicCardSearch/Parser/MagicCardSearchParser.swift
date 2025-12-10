internal enum Token {
    case void
    case term(String)
}

func doubleQuoteIfNecessary(_ string: String) -> String {
    return string.contains(" ") ? "\"\(string)\"" : string
}

/// Quoting to preserve whitespace not required; any quotes present will be assumed to be part of the term to search for.
enum SearchFilter: Equatable, Hashable, Codable {
    case name(String)
    case keyValue(String, Comparison, String)

    static func tryParseUnambiguous(_ input: String) -> SearchFilter? {
        return try? parse(input)
    }

    // TODO: This and the previous method should be single-quote aware too, probably.
    var queryStringWithEditingRange: (String, Range<String.Index>) {
        switch self {
        case .name(let name):
            return if name.contains(" ") {
                ("\"\(name)\"", name.index(after: name.startIndex)..<name.index(before: name.endIndex))
            } else {
                (name, name.startIndex..<name.endIndex)
            }
        case .keyValue(let key, let comparison, let value):
            let prefix = "\(key)\(comparison.symbol)"
            if value.contains(" ") {
                let formatted = "\(prefix)\"\(value)\""
                return (
                    formatted,
                    formatted.index(after: prefix.endIndex)..<formatted.index(before: formatted.endIndex)
                )
            } else {
                let formatted = "\(prefix)\(value)"
                return (
                    formatted,
                    prefix.endIndex..<formatted.endIndex
                )
            }
        }
    }
}

enum Comparison: String, Codable, Hashable {
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
    try lexer.tokenize(input) { token, code in
        try parser.consume(token: token, code: code)
    }
    return try parser.endParsing()
}
