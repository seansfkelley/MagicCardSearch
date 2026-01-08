import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "ParenthesizedQuery")

struct Filter: Equatable, Sendable, CustomStringConvertible {
    let negated: Bool
    let content: FilterContent
    
    var description: String {
        descriptionWithContext(needsParentheses: false)
    }
    
    fileprivate func descriptionWithContext(needsParentheses: Bool) -> String {
        let contentDescription = content.descriptionWithContext(needsParentheses: needsParentheses && negated)
        
        if negated {
            // If the content has multiple items (conjunction/disjunction with > 1 element), wrap in parens
            switch content {
            case .basic:
                return "-\(contentDescription)"
            case .conjunction(let filters), .disjunction(let filters):
                if filters.count > 1 {
                    return "-(\(contentDescription))"
                } else {
                    return "-\(contentDescription)"
                }
            }
        } else {
            return contentDescription
        }
    }
    
    func toSearchFilter() -> SearchFilter? {
        switch content {
        case .basic(let string):
            return PartialSearchFilter.from(string).toComplete().map { filter in
                // Apply negation from the Filter level
                if negated {
                    // Toggle the negation in the filter
                    switch filter {
                    case .name(let name):
                        return .name(.init(!name.negated, name.isExact, name.name))
                    case .basic(let basic):
                        return .basic(.init(!basic.negated, basic.filter, basic.comparison, basic.query))
                    case .regex(let regex):
                        return .regex(.init(!regex.negated, regex.filter, regex.comparison, regex.regex))
                    case .disjunction(let disjunction):
                        return .disjunction(.init(!disjunction.negated, disjunction.clauses))
                    }
                } else {
                    return filter
                }
            }
            
        case .conjunction(let filters):
            let converted = filters.compactMap { $0.toSearchFilter() }
            guard converted.count == filters.count else { return nil }
            
            // Create a conjunction
            let clauses = converted.map { SearchFilter.Conjunction.Clause.filter($0) }
            let conjunction = SearchFilter.Conjunction(clauses)
            
            // If negated, wrap in a negated disjunction containing this conjunction
            if negated {
                return .disjunction(.init(true, [conjunction]))
            } else {
                // Return as a disjunction with a single conjunction (to match SearchFilter structure)
                return .disjunction(.init(false, [conjunction]))
            }
            
        case .disjunction(let filters):
            let converted = filters.compactMap { $0.toSearchFilter() }
            guard converted.count == filters.count else { return nil }
            
            // Each filter becomes a conjunction with a single clause
            let conjunctions = converted.map { filter in
                SearchFilter.Conjunction([.filter(filter)])
            }
            
            return .disjunction(.init(negated, conjunctions))
        }
    }
}

enum FilterContent: Equatable, Sendable, CustomStringConvertible {
    case basic(String)
    case conjunction([Filter])
    case disjunction([Filter])
    
    var description: String {
        descriptionWithContext(needsParentheses: false)
    }
    
    fileprivate func descriptionWithContext(needsParentheses: Bool) -> String {
        switch self {
        case .basic(let string):
            return string
            
        case .conjunction(let filters):
            if filters.count == 1 {
                return filters[0].descriptionWithContext(needsParentheses: false)
            }
            
            // Each filter in a conjunction needs to know it's in a conjunction context
            // so disjunctions within can add parens if needed
            let joined = filters.map { filter in
                // Disjunctions inside conjunctions need parentheses
                switch filter.content {
                case .disjunction(let innerFilters) where innerFilters.count > 1:
                    return filter.descriptionWithContext(needsParentheses: true)
                default:
                    return filter.descriptionWithContext(needsParentheses: false)
                }
            }.joined(separator: " ")
            
            return needsParentheses ? "(\(joined))" : joined
            
        case .disjunction(let filters):
            if filters.count == 1 {
                return filters[0].descriptionWithContext(needsParentheses: needsParentheses)
            }
            
            let joined = filters.map { $0.descriptionWithContext(needsParentheses: false) }.joined(separator: " or ")
            
            return needsParentheses ? "(\(joined))" : joined
        }
    }
}

// BELOW THIS LINE IS OLD

struct ParenthesizedConjunction: Equatable, CustomStringConvertible, Sendable {
    enum Clause: Equatable, CustomStringConvertible, Sendable {
        case filter(String)
        case disjunction(ParenthesizedDisjunction)

        var description: String {
            descriptionWithContext(inConjunction: false)
        }

        fileprivate func descriptionWithContext(inConjunction: Bool) -> String {
            switch self {
            case .filter(let string):
                string
            case .disjunction(let disjunction):
                disjunction.descriptionWithContext(needsParentheses: inConjunction && disjunction.clauses.count > 1)
            }
        }

        func toSearchFilter() -> SearchFilter.Conjunction.Clause? {
            switch self {
            case .filter(let string): PartialSearchFilter.from(string).toComplete().map { .filter($0) }
            case .disjunction(let disjunction): disjunction.toSearchFilter().map { .disjunction($0) }
            }
        }
    }

    let negated: Bool
    let clauses: [Clause]

    var description: String {
        descriptionWithContext(needsParentheses: false)
    }

    fileprivate func descriptionWithContext(needsParentheses: Bool) -> String {
        clauses.map { $0.descriptionWithContext(inConjunction: clauses.count > 1) }.joined(separator: " ")
    }

    func toSearchFilter() -> SearchFilter.Conjunction? {
        let transformedClauses = clauses.compactMap { $0.toSearchFilter() }
        return if transformedClauses.count == clauses.count {
            .init(transformedClauses)
        } else {
            nil
        }
    }

    init(_ negated: Bool, _ clauses: [Clause]) {
        self.negated = negated
        self.clauses = clauses
    }

    static func tryParse(_ input: String) -> ParenthesizedDisjunction? {
        let parser = ParenthesizedQueryParser()

        let trimmedInput = input.trimmingCharacters(in: .whitespaces)

        do {
            for (token, code) in try lexParenthesizedQuery(trimmedInput) {
                try parser.consume(token: token, code: code)
            }
            return try parser.endParsing()
        } catch {
            logger.debug("failed to parse disjunction error=\(error)")
            return nil
        }
    }
}


struct ParenthesizedDisjunction: Equatable, CustomStringConvertible, Sendable {
    let negated: Bool
    let clauses: [ParenthesizedConjunction]
    
    var description: String {
        descriptionWithContext(needsParentheses: false)
    }

    fileprivate func descriptionWithContext(needsParentheses: Bool) -> String {
        if clauses.count == 1 {
            let inner = clauses[0].descriptionWithContext(needsParentheses: false)
            return if negated && clauses[0].clauses.count > 1 {
                "-(\(inner))"
            } else if negated {
                "-\(inner)"
            } else {
                inner
            }
        }
        
        let joined = clauses.map { $0.descriptionWithContext(needsParentheses: false) }.joined(separator: " or ")
        
        return if negated {
            "-(\(joined))"
        } else if needsParentheses {
            "(\(joined))"
        } else {
            joined
        }
    }

    func toSearchFilter() -> SearchFilter.Disjunction? {
        let transformedClauses = clauses.compactMap { $0.toSearchFilter() }
        return if transformedClauses.count == clauses.count {
            .init(negated, transformedClauses)
        } else {
            nil
        }
    }

    init(_ negated: Bool, _ clauses: [ParenthesizedConjunction]) {
        self.negated = negated
        self.clauses = clauses
    }
}
