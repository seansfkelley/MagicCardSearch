func doubleQuoteIfNecessary(_ string: String) -> String {
    return string.contains(" ") ? "\"\(string)\"" : string
}

struct SearchFilter: Equatable, Hashable, Codable, CustomStringConvertible {
    let negated: Bool
    let content: SearchFilterContent
    
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
enum SearchFilterContent: Equatable, Hashable, Codable, CustomStringConvertible {
    case name(String, Bool)
    case regex(String, Comparison, String)
    case keyValue(String, Comparison, String)
    case parenthesized(String) // TODO: Recursive case!
    
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
            return "\(key)\(comparison)\(regex)"
        case .keyValue(let key, let comparison, let value):
            return if value.contains(" ") {
                "\(key)\(comparison)\"\(value)\""
            } else {
                "\(key)\(comparison)\(value)"
            }
        case .parenthesized(let content):
            return "(\(content))"
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
        case .parenthesized:
            left = string.index(after: string.startIndex)
            right = string.index(before: string.endIndex)
        }
        
        return left..<right
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

enum Comparison: String, Codable, Hashable, Equatable, CustomStringConvertible {
    case including = ":"
    case equal = "="
    case notEqual = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="

    var description: String { rawValue }
}
