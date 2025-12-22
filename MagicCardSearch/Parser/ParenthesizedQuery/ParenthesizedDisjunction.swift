import Logging

private let logger = Logger(label: "ParenthesizedDisjunction")

struct ParenthesizedDisjunction: Equatable {
    let negated: Bool
    let clauses: [ParenthesizedConjunction]
    
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

struct ParenthesizedConjunction: Equatable {
    enum Clause: Equatable {
        case filter(Range<String.Index>)
        case disjunction(ParenthesizedDisjunction)
    }
    
    let clauses: [Clause]
    
    init(_ clauses: [Clause]) {
        self.clauses = clauses
    }
}
