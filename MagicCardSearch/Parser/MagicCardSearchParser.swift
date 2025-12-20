typealias Token = String

func doubleQuoteIfNecessary(_ string: String) -> String {
    return string.contains(" ") ? "\"\(string)\"" : string
}

enum SearchFilter: Equatable, Hashable, Codable {
    case basic(SearchFilterContent)
    case negated(SearchFilterContent)
    
    static func tryParseUnambiguous(_ input: String) -> SearchFilter? {
        return try? parse(input)
    }
    
    var queryStringWithEditingRange: (String, Range<String.Index>) {
        switch self {
        case .basic(let content):
            return content.queryStringWithEditingRange
        case .negated(let content):
            let (string, range) = content.queryStringWithEditingRange
            let negatedString = "-\(string)"
            return (
                negatedString,
                negatedString
                    .index(after: range.lowerBound)..<negatedString
                    .index(after: range.upperBound)
            )
        }
    }
    
    var isKnownFilterType: Bool {
        return switch self {
        case .basic(let content): content.isKnownFilterType
        case .negated(let content): content.isKnownFilterType
        }
    }
}

/// Quoting to preserve whitespace not required; any quotes present will be assumed to be part of the term to search for.
enum SearchFilterContent: Equatable, Hashable, Codable {
    case name(String, Bool)
    case regex(String, Comparison, String)
    case keyValue(String, Comparison, String)
    case parenthesized(String)
    
    var queryStringWithEditingRange: (String, Range<String.Index>) {
        switch self {
        case .name(let name, let isExact):
            var prefix = ""
            var suffix = ""
            if name.contains(" ") {
                prefix = "\""
                suffix = "\""
            }
            if isExact {
                prefix = "!\(prefix)"
            }
            let prefixedName = "\(prefix)\(name)"
            return (
                "\(prefixedName)\(suffix)",
                prefix.endIndex..<prefixedName.endIndex,
            )
        case .regex(let key, let comparison, let regex):
            let prefix = "\(key)\(comparison.symbol)"
            let formatted = "\(prefix)\(regex)"
            return (
                formatted,
                formatted.index(after: prefix.endIndex)..<formatted.index(before: formatted.endIndex)
            )
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
        case .parenthesized(let content):
            return (
                content,
                content.index(after: content.startIndex)..<content.index(before: content.endIndex)
            )
        }
    }
    
    var isKnownFilterType: Bool {
        return switch self {
        case .name: true
        case .regex(let key, _, _): scryfallFilterByType[key.lowercased()] != nil
        case .keyValue(let key, _, _): scryfallFilterByType[key.lowercased()] != nil
        case .parenthesized: true // give up
        }
    }
}

enum Comparison: String, Codable, Hashable, Equatable {
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

internal func parseQuoted(_ input: String) -> LexedTokenData? {
    // Assumes exactly 1 set of quotes on each side.
    return (
        String(input[input.index(after: input.startIndex)..<input.index(before: input.endIndex)]),
        .QuotedLiteral
    )
}

internal func parseRegex(_ input: String) -> LexedTokenData? {
    return (input, .Regex)
}

internal func parseParenthesized(_ input: String) -> LexedTokenData? {
    return (input, .Parenthesized)
}

internal func parseAlphanumeric(_ input: String) -> LexedTokenData? {
    return (input, .Alphanumeric)
}

internal func parseComparison(_ input: String) -> LexedTokenData? {
    return (input, .Comparison)
}

internal func parseSingleNonPairing(_ input: String) -> LexedTokenData? {
    return (input, .SingleNonPairing)
}

internal func parseUnclosedPairing(_ input: String) -> LexedTokenData? {
    return (input, .UnclosedPairing)
}

private func parse(_ input: String) throws -> SearchFilter {
    let lexer = CitronLexer<LexedTokenData>(rules: [
        .regexPattern(#"'[^']*'"#, parseQuoted), // highest priority
        .regexPattern(#""[^"]*""#, parseQuoted), // highest priority
        .regexPattern(#"/[^/]*/"#, parseRegex), // highest priority
        .regexPattern(#"\([^\)]*\)"#, parseParenthesized), // highest priority
        .regexPattern(#"[a-zA-Z0-9]+"#, parseAlphanumeric),
        .string("-", ("-", .Minus)),
        .regexPattern(#"<=|<|>=|>|!=|=|:"#, parseComparison),
        .string("!", ("!", .Bang)), // must come after operators!
        .regexPattern(#"[^'"/ \t\n\(\)]"#, parseSingleNonPairing), // TODO: Can do a class of whitespace better than this?
        .regexPattern(#"['"/\(\)]"#, parseUnclosedPairing),
    ])
    
    let parser = MagicCardSearchGrammar()
    try lexer.tokenize(input) { token, code in
        try parser.consume(token: token, code: code)
    }
    return try parser.endParsing()
}
