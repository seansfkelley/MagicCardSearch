struct SearchFilter: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
    let negated: Bool
    let content: SearchFilterContent
    
    init(_ content: SearchFilterContent) {
        self.negated = false
        self.content = content
    }
    
    init(_ negated: Bool, _ content: SearchFilterContent) {
        self.negated = negated
        self.content = content
    }
    
    var description: String {
        "\(negated ? "-" : "")\(content)"
    }
    
    var suggestedEditingRange: Range<String.Index> {
        let string = description
        let contentRange = content.suggestedEditingRange
        if negated {
            return contentRange.offset(with: string, by: 1)
        } else {
            return contentRange
        }
    }
}

/// Quoting to preserve whitespace not required; any quotes present will be assumed to be part of the term to search for.
enum SearchFilterContent: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
    case name(String, Bool)
    case regex(String, Comparison, String)
    case keyValue(String, Comparison, String)
    case disjunction(Disjunction)

    struct Disjunction: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
        let clauses: [Conjunction]

        var description: String {
            descriptionWithContext(needsParentheses: false)
        }

        fileprivate func descriptionWithContext(needsParentheses: Bool) -> String {
            if clauses.count == 1 {
                return clauses[0].descriptionWithContext(needsParentheses: false)
            }
            
            let joined = clauses.map { $0.descriptionWithContext(needsParentheses: false) }.joined(separator: " or ")

            return needsParentheses ? "(\(joined))" : joined
        }

        var isKnownFilterType: Bool {
            clauses.allSatisfy { $0.isKnownFilterType }
        }

        init(_ clauses: [Conjunction]) {
            self.clauses = clauses
        }
    }

    struct Conjunction: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
        enum Clause: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
            case filter(SearchFilter)
            case disjunction(Disjunction)

            var description: String {
                descriptionWithContext(inConjunction: false)
            }

            fileprivate func descriptionWithContext(inConjunction: Bool) -> String {
                switch self {
                case .filter(let filter):
                    filter.description
                case .disjunction(let disjunction):
                    disjunction.descriptionWithContext(needsParentheses: inConjunction && disjunction.clauses.count > 1)
                }
            }

            var isKnownFilterType: Bool {
                switch self {
                case .filter(let filter): filter.content.isKnownFilterType
                case .disjunction(let disjunction): disjunction.isKnownFilterType
                }
            }
        }

        let clauses: [Clause]

        var description: String {
            descriptionWithContext(needsParentheses: false)
        }

        fileprivate func descriptionWithContext(needsParentheses: Bool) -> String {
            clauses.map { $0.descriptionWithContext(inConjunction: clauses.count > 1) }.joined(separator: " ")
        }

        var isKnownFilterType: Bool {
            clauses.allSatisfy { $0.isKnownFilterType }
        }

        init(_ clauses: [Clause]) {
            self.clauses = clauses
        }
    }

    var description: String {
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
            return "\(prefix)\(name)\(suffix)"
        case .regex(let key, let comparison, let regex):
            return "\(key)\(comparison)/\(regex)/"
        case .keyValue(let key, let comparison, let value):
            return if value.contains(" ") {
                "\(key)\(comparison)\"\(value)\""
            } else {
                "\(key)\(comparison)\(value)"
            }
        case .disjunction(let disjunction):
            return disjunction.descriptionWithContext(needsParentheses: true)
        }
    }
    
    var suggestedEditingRange: Range<String.Index> {
        let string = description
        
        let left: String.Index
        let right: String.Index
        
        switch self {
        case .name(let name, let isExact):
            let needsQuotes = name.contains(" ")
            left = string.index(string.startIndex, offsetBy: (isExact ? 1 : 0) + (needsQuotes ? 1 : 0))
            right = string.index(string.endIndex, offsetBy: needsQuotes ? -1 : 0)
        case .keyValue(let filter, let comparison, let value):
            let needsQuotes = value.contains(" ")
            left = string.index(string.startIndex, offsetBy: filter.count + comparison.description.count + (needsQuotes ? 1 : 0))
            right = string.index(string.endIndex, offsetBy: needsQuotes ? -1 : 0)
        case .regex(let filter, let comparison, _):
            left = string.index(string.startIndex, offsetBy: filter.count + comparison.description.count + 1)
            right = string.index(string.endIndex, offsetBy: -1)
        case .disjunction:
            left = string.index(string.startIndex, offsetBy: 1)
            right = string.index(string.endIndex, offsetBy: -1)
        }
        
        return left..<right
    }
    
    var isKnownFilterType: Bool {
        return switch self {
        case .name: true
        case .regex(let key, _, _): scryfallFilterByType[key.lowercased()] != nil
        case .keyValue(let key, _, _): scryfallFilterByType[key.lowercased()] != nil
        case .disjunction(let disjunction): disjunction.isKnownFilterType
        }
    }
}

enum Comparison: String, Codable, Hashable, Equatable, CustomStringConvertible, Sendable {
    case including = ":"
    case equal = "="
    case notEqual = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="

    var description: String { rawValue }
}
