protocol SearchFilterContent: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
    var suggestedEditingRange: Range<String.Index> { get }
    var isKnownFilterType: Bool { get }
}

private func isScryfallFilter(_ filter: String) -> Bool {
    scryfallFilterByType[filter.lowercased()] != nil
}

/// Quoting to preserve whitespace not required; any quotes present will be assumed to be part of the term to search for.
enum SearchFilter: SearchFilterContent {
    case name(Name)
    case basic(Basic)
    case regex(Regex)
    case disjunction(Disjunction)

    var content: any SearchFilterContent {
        switch self {
        case .name(let name): name
        case .basic(let basic): basic
        case .regex(let regex): regex
        case .disjunction(let disjunction): disjunction
        }
    }

    var description: String { content.description }
    var suggestedEditingRange: Range<String.Index> { content.suggestedEditingRange }
    var isKnownFilterType: Bool { content.isKnownFilterType }

    struct Name: SearchFilterContent {
        let negated: Bool
        let isExact: Bool
        let name: String

        var description: String {
            var prefix = ""
            var suffix = ""
            if negated {
                prefix = "-"
            }
            if name.contains(" ") {
                prefix = "\"\(prefix)"
                suffix = "\""
            }
            if isExact {
                prefix = "!\(prefix)"
            }
            return "\(prefix)\(name)\(suffix)"
        }

        var suggestedEditingRange: Range<String.Index> {
            let string = description
            let needsQuotes = name.contains(" ")
            return string.range.inset(
                with: string,
                left: (negated ? 1 : 0) + (isExact ? 1 : 0) + (needsQuotes ? 1 : 0),
                right: needsQuotes ? 1 : 0,
            )
        }

        var isKnownFilterType: Bool { true }
    }

    struct Regex: SearchFilterContent {
        let negated: Bool
        let filter: String
        let comparison: Comparison
        let regex: String

        var description: String {
            "\(negated ? "-" : "")\(filter)\(comparison)/\(regex)/"
        }

        var suggestedEditingRange: Range<String.Index> {
            let string = description
            return string.range.inset(
                with: string,
                left: (negated ? 1 : 0) + filter.count + comparison.description.count + 1,
                right: 1,
            )
        }

        var isKnownFilterType: Bool { isScryfallFilter(filter) }
    }

    struct Basic: SearchFilterContent {
        let negated: Bool
        let filter: String
        let comparison: Comparison
        let query: String

        var description: String {
            return if query.contains(" ") {
                "\(filter)\(comparison)\"\(query)\""
            } else {
                "\(filter)\(comparison)\(query)"
            }
        }

        var suggestedEditingRange: Range<String.Index> {
            let string = description
            let needsQuotes = query.contains(" ")
            return string.range.inset(
                with: string,
                left: (negated ? 1 : 0) + (needsQuotes ? 1 : 0) + filter.count + comparison.description.count,
                right: needsQuotes ? 1 : 0,
            )
        }

        var isKnownFilterType: Bool { isScryfallFilter(filter) }
    }

    struct Disjunction: SearchFilterContent {
        let negated: Bool
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

        var suggestedEditingRange: Range<String.Index> {
            let string = description
            return string.range.inset(
                with: string,
                left: (negated ? 1 : 0) + (string.firstMatch(of: /^-?\(/) != nil ? 1 : 0),
                right: string.firstMatch(of: /\)$/) != nil ? 1 : 0,
            )
        }

        var isKnownFilterType: Bool {
            clauses.allSatisfy { $0.isKnownFilterType }
        }

        init(_ negated: Bool, _ clauses: [Conjunction]) {
            self.negated = negated
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
                case .filter(let filter): filter.isKnownFilterType
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
