//
//  PartialSearchFilter.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-21.
//
import Logging

private let logger = Logger(label: "PartialSearchFilter")

struct PartialSearchFilter: Equatable {
    enum PartialComparison: String, Equatable {
        case including = ":"
        case equal = "="
        case notEqual = "!="
        case lessThan = "<"
        case lessThanOrEqual = "<="
        case greaterThan = ">"
        case greaterThanOrEqual = ">="
        case incompleteNotEqual = "!"
        
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
    
    enum PartialTerm: Equatable {
        enum QuotingType: Equatable {
            case singleQuote, doubleQuote, forwardSlash
        }
        
        case unquoted(String)
        case unterminated(QuotingType, String)
        case balanced(QuotingType, String)
        
        var quotingType: QuotingType? {
            switch self {
            case .unquoted: nil
            case .unterminated(let quote, _): quote
            case .balanced(let quote, _): quote
            }
        }
    
        func toComplete() -> String? {
            switch self {
            case .unquoted(let content): content
            case .unterminated: nil
            case .balanced(let quote, let content):
                switch quote {
                case .forwardSlash: "/\(content)/"
                case .singleQuote, .doubleQuote: content
                }
            }
        }
    }
    
    enum Content: Equatable {
        case name(Bool, PartialTerm)
        case filter(String, PartialComparison, PartialTerm)
        
        func toComplete() -> SearchFilterContent? {
            switch self {
            case .name(let exact, let term):
                if let completeTerm = term.toComplete() {
                    return .name(completeTerm, exact)
                } else {
                    return nil
                }
            case .filter(let field, let comparison, let term):
                if let completeTerm = term.toComplete(), let completeComparison = comparison.toComplete() {
                    return switch term.quotingType {
                    case .singleQuote, .doubleQuote: .keyValue(field, completeComparison, completeTerm)
                    case .forwardSlash: .regex(field, completeComparison, completeTerm)
                    case nil: completeTerm.isEmpty ? nil : .keyValue(field, completeComparison, completeTerm)
                    }
                } else {
                    return nil
                }
            }
        }
    }
    
    let negated: Bool
    let content: Content
    
    func toComplete() -> SearchFilter? {
        if let completeContent = content.toComplete() {
            return negated ? .negated(completeContent) : .basic(completeContent)
        } else {
            return nil
        }
    }
    
    static func from(_ input: String) -> PartialSearchFilter {
        var remaining: Substring = input[input.startIndex...]
        
        let negated: Bool
        if !remaining.isEmpty && remaining.first == "-" {
            negated = true
            remaining = remaining.suffix(from: remaining.index(after: remaining.startIndex))
        } else {
            negated = false
        }
        
        if !remaining.isEmpty && remaining.first == "!" {
            return .init(
                negated: negated,
                content: .name(
                    true,
                    parseBalancedString(String(remaining.suffix(from: remaining.index(after: remaining.startIndex)))),
                )
            )
        }
        
        do {
            if let match = try /^([a-zA-Z]+)(<=|<|>=|>|!=|=|!|:)/.prefixMatch(in: remaining) {
                let filter = String(match.output.1)
                let comparison = PartialSearchFilter.PartialComparison(rawValue: String(match.output.2))!
                let value = parseBalancedString(String(remaining[match.range.upperBound...]))
                return .init(
                    negated: negated,
                    content: .filter(filter, comparison, value),
                )
            }
        } catch {
            logger.error("unexpected error; this code should not ever throw", metadata: [
                "error": "\(error)",
            ])
        }
        
        return .init(
            negated: negated,
            content: .name(
                false,
                parseBalancedString(String(remaining)),
            ),
        )
    }
}

internal func parseBalancedString(_ input: String) -> PartialSearchFilter.PartialTerm {
    if let match = input.wholeMatch(of: /^'([^']*)('?)$/) {
        let (_, content, close) = match.output
        return close.isEmpty
        ? .unterminated(.singleQuote, String(content))
        : .balanced(.singleQuote, String(content))
    } else if let match = input.wholeMatch(of: /^"([^"]*)("?)$/) {
        let (_, content, close) = match.output
        return close.isEmpty
        ? .unterminated(.doubleQuote, String(content))
        : .balanced(.doubleQuote, String(content))
    } else if let match = input.wholeMatch(of: /^\/([^\/]*)(\/?)$/) {
        let (_, content, close) = match.output
        return close.isEmpty
        ? .unterminated(.forwardSlash, String(content))
        : .balanced(.forwardSlash, String(content))
    } else {
        return .unquoted(input)
    }
}
