import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "PartialFilterTerm")

public struct PartialFilterTerm: Sendable, Equatable, CustomStringConvertible {
    enum PartialComparison: String, Equatable, CustomStringConvertible {
        case including = ":"
        case equal = "="
        case notEqual = "!="
        case lessThan = "<"
        case lessThanOrEqual = "<="
        case greaterThan = ">"
        case greaterThanOrEqual = ">="
        case incompleteNotEqual = "!"
        
        var description: String {
            self.rawValue
        }
        
        func toComplete() -> Comparison? {
            switch self {
            case .including: .including
            case .equal: .equal
            case .notEqual: .notEqual
            case .lessThan: .lessThan
            case .lessThanOrEqual: .lessThanOrEqual
            case .greaterThan: .greaterThan
            case .greaterThanOrEqual: .greaterThanOrEqual
            case .incompleteNotEqual: nil
            }
        }
    }
    
    enum PartialTerm: Equatable, CustomStringConvertible {
        enum QuotingType: String, Equatable, CustomStringConvertible {
            case singleQuote = "'"
            case doubleQuote = "\""
            case forwardSlash = "/"
            
            var description: String {
                self.rawValue
            }

            var opposite: QuotingType? {
                switch self {
                case .singleQuote: .doubleQuote
                case .doubleQuote: .singleQuote
                case .forwardSlash: nil
                }
            }
        }
        
        case bare(String)
        case unclosed(QuotingType, String)
        case unopened(QuotingType, String)
        case balanced(QuotingType, String)
        
        var description: String {
            switch self {
            case .bare(let content): content
            case .unclosed(let quote, let content): "\(quote)\(content)"
            case .unopened(let quote, let content): "\(content)\(quote)"
            case .balanced(let quote, let content): "\(quote)\(content)\(quote)"
            }
        }
        
        var quotingType: QuotingType? {
            switch self {
            case .bare: nil
            case .unclosed(let quote, _): quote
            case .unopened(let quote, _): quote
            case .balanced(let quote, _): quote
            }
        }
        
        var incompleteContent: String {
            switch self {
            case .bare(let content): content
            case .unclosed(_, let content): content
            case .unopened(_, let content): content
            case .balanced(_, let content): content
            }
        }
    
        func toComplete(autocloseQuotes: Bool = false) -> String? {
            switch self {
            case .bare(let content): content
            case .unclosed(_, let content): autocloseQuotes ? content : nil
            case .unopened: nil // we really can't guess where the quotes should start, so don't
            case .balanced(_, let content): content
            }
        }
    }
    
    enum Content: Equatable, CustomStringConvertible {
        case name(Bool, PartialTerm)
        case filter(String, PartialComparison, PartialTerm)
        
        var description: String {
            switch self {
            case .name(let exact, let term): "\(exact ? "!" : "")\(term)"
            case .filter(let field, let comparison, let term): "\(field)\(comparison)\(term)"
            }
        }

        var term: PartialTerm {
            switch self {
            case .name(_, let term): term
            case .filter(_, _, let term): term
            }
        }
    }
    
    let polarity: Polarity
    let content: Content
    
    public var description: String { "\(polarity)\(content)" }

    func toComplete(autocloseQuotes: Bool = false) -> FilterTerm? {
        switch content {
        case .name(let exact, let term):
            if let completeTerm = term.toComplete(autocloseQuotes: autocloseQuotes) {
                return .name(polarity, exact, completeTerm)
            } else {
                return nil
            }
        case .filter(let field, let comparison, let term):
            if let completeTerm = term.toComplete(autocloseQuotes: autocloseQuotes), let completeComparison = comparison.toComplete() {
                return switch term.quotingType {
                case .singleQuote, .doubleQuote:
                    .basic(polarity, field, completeComparison, completeTerm)
                case .forwardSlash:
                    .regex(polarity, field, completeComparison, completeTerm)
                case nil:
                    completeTerm.isEmpty ? nil : .basic(polarity, field, completeComparison, completeTerm)
                }
            } else {
                return nil
            }
        }
    }
    
    static func from(_ input: String) -> PartialFilterTerm {
        var remaining: Substring = input[input.startIndex...]
        
        let polarity: Polarity
        if !remaining.isEmpty && remaining.first == "-" {
            polarity = .negative
            remaining = remaining.suffix(from: remaining.index(after: remaining.startIndex))
        } else {
            polarity = .positive
        }
        
        if !remaining.isEmpty && remaining.first == "!" {
            return .init(
                polarity: polarity,
                content: .name(
                    true,
                    matchPartialTerm(
                        String(remaining.suffix(from: remaining.index(after: remaining.startIndex))),
                        treatingRegexesAsLiterals: true,
                    ),
                )
            )
        }
        
        do {
            if let match = try /^([a-zA-Z]+)(<=|<|>=|>|!=|=|!|:)/.prefixMatch(in: remaining) {
                let filter = String(match.output.1)
                let comparison = PartialFilterTerm.PartialComparison(rawValue: String(match.output.2))!
                let value = matchPartialTerm(String(remaining[match.range.upperBound...]))
                return .init(
                    polarity: polarity,
                    content: .filter(filter, comparison, value),
                )
            }
        } catch {
            logger.error("unexpected error; this code should not ever throw error=\(error)")
        }
        
        return .init(
            polarity: polarity,
            content: .name(
                false,
                matchPartialTerm(String(remaining), treatingRegexesAsLiterals: true),
            ),
        )
    }
}

func matchPartialTerm(_ input: String, treatingRegexesAsLiterals: Bool = false) -> PartialFilterTerm.PartialTerm {
    if let match = input.wholeMatch(of: /^'([^']*)('?)$/) {
        let (_, content, close) = match.output
        return close.isEmpty
        ? .unclosed(.singleQuote, String(content))
        : .balanced(.singleQuote, String(content))
    } else if let match = input.wholeMatch(of: /^"([^"]*)("?)$/) {
        let (_, content, close) = match.output
        return close.isEmpty
        ? .unclosed(.doubleQuote, String(content))
        : .balanced(.doubleQuote, String(content))
    } else if let match = input.wholeMatch(of: /^([^"]+)"$/) {
        let (_, content) = match.output
        // There is no case for unintiated single-quote; such a case is actually considered a usage
        // of an apostrophe and therefore would fall into the .bare case.
        return .unopened(.doubleQuote, String(content))
    } else if !treatingRegexesAsLiterals, let match = input.wholeMatch(of: /^\/([^\/]*)(\/?)$/) {
        let (_, content, close) = match.output
        return close.isEmpty
        ? .unclosed(.forwardSlash, String(content))
        : .balanced(.forwardSlash, String(content))
    } else {
        return .bare(input)
    }
}
