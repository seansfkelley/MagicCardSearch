import Logging

private let logger = Logger(label: "ParenthesizedDisjunction")

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
    
    init(_ negated: Bool, _ clauses: [ParenthesizedConjunction]) {
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
            logger.debug("failed to parse disjunction", metadata: [
                "error": "\(error)",
            ])
            return nil
        }
    }
}

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
    }
    
    let clauses: [Clause]
    
    var description: String {
        descriptionWithContext(needsParentheses: false)
    }
    
    fileprivate func descriptionWithContext(needsParentheses: Bool) -> String {
        clauses.map { $0.descriptionWithContext(inConjunction: clauses.count > 1) }.joined(separator: " ")
    }
    
    init(_ clauses: [Clause]) {
        self.clauses = clauses
    }
}
