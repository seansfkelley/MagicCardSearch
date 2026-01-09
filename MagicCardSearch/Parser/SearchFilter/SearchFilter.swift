protocol SearchFilterContent: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
    var suggestedEditingRange: Range<String.Index> { get }
    var isKnownFilterType: Bool { get }
}

private func isScryfallFilter(_ filter: String) -> Bool {
    scryfallFilterByType[filter.lowercased()] != nil
}

public enum SearchFilter: SearchFilterContent {
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

    public var description: String { content.description }
    var suggestedEditingRange: Range<String.Index> { content.suggestedEditingRange }
    var isKnownFilterType: Bool { content.isKnownFilterType }

    static func name(_ negated: Bool, _ isExact: Bool, _ name: String) -> SearchFilter {
        .name(Name(negated, isExact, name))
    }
    
    static func basic(_ negated: Bool, _ filter: String, _ comparison: Comparison, _ query: String) -> SearchFilter {
        .basic(Basic(negated, filter, comparison, query))
    }
    
    static func regex(_ negated: Bool, _ filter: String, _ comparison: Comparison, _ regex: String) -> SearchFilter {
        .regex(Regex(negated, filter, comparison, regex))
    }
    
    static func disjunction(_ negated: Bool, _ clauses: [Conjunction]) -> SearchFilter {
        .disjunction(Disjunction(negated, clauses))
    }

    public struct Name: SearchFilterContent {
        let negated: Bool
        let isExact: Bool
        let name: String

        init(_ negated: Bool, _ isExact: Bool, _ name: String) {
            self.negated = negated
            self.isExact = isExact
            self.name = name
        }

        public var description: String {
            var prefix = ""
            var suffix = ""
            if negated {
                prefix = "-"
            }
            if isExact {
                prefix = "\(prefix)!"
            }
            if name.contains(" ") {
                prefix = "\(prefix)\""
                suffix = "\""
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

    public struct Regex: SearchFilterContent {
        let negated: Bool
        let filter: String
        let comparison: Comparison
        let regex: String

        init(_ negated: Bool, _ filter: String, _ comparison: Comparison, _ regex: String) {
            self.negated = negated
            self.filter = filter
            self.comparison = comparison
            self.regex = regex
        }

        public var description: String {
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

    public struct Basic: SearchFilterContent {
        let negated: Bool
        let filter: String
        let comparison: Comparison
        let query: String

        init(_ negated: Bool, _ filter: String, _ comparison: Comparison, _ query: String) {
            self.negated = negated
            self.filter = filter
            self.comparison = comparison
            self.query = query
        }

        public var description: String {
            return if query.contains(" ") {
                "\(negated ? "-" : "")\(filter)\(comparison)\"\(query)\""
            } else {
                "\(negated ? "-" : "")\(filter)\(comparison)\(query)"
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

    public struct Disjunction: SearchFilterContent {
        let negated: Bool
        let clauses: [Conjunction]

        public var description: String {
            descriptionWithContext(needsParentheses: true)
        }

        fileprivate func descriptionWithContext(needsParentheses: Bool) -> String {
            if clauses.count == 1 {
                let content = clauses[0].descriptionWithContext(needsParentheses: false)
                return needsParentheses || negated ? "\(negated ? "-" : "")(\(content))" : content
            }
            
            let joined = clauses.map { $0.descriptionWithContext(needsParentheses: false) }.joined(separator: " or ")
            
            return needsParentheses || negated ? "\(negated ? "-" : "")(\(joined))" : joined
        }

        var suggestedEditingRange: Range<String.Index> {
            let string = description
            return string.range.inset(
                with: string,
                left: (negated ? 1 : 0) + 1,
                right: 1,
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

public enum Comparison: String, Codable, Hashable, Equatable, CustomStringConvertible, Sendable {
    case including = ":"
    case equal = "="
    case notEqual = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="

    public var description: String { rawValue }
}
