struct ParenthesizedConjunction {
    enum Clause {
        case filter(Range<String.Index>)
        case disjunction(ParenthesizedDisjunction)
    }
    
    let clauses: [Clause]
    
    init(_ clauses: [Clause]) {
        self.clauses = clauses
    }
}

struct ParenthesizedDisjunction {
    let negated: Bool
    let clauses: [ParenthesizedConjunction]
    
    init(_ negated: Bool, _ clauses: [ParenthesizedConjunction]) {
        self.negated = negated
        self.clauses = clauses
    }
    
    static func tryParse(_ input: String) throws -> ParenthesizedDisjunction {
        let parser = ParenthesizedQueryParser()
        
        let trimmedInput = input.trimmingCharacters(in: .whitespaces)
        let prefixOffset = input.prefixMatch(of: /\s*/)?.count ?? 0

        for (token, code) in try lexParenthesizedQuery(trimmedInput) {
            try parser.consume(token: token, code: code)
        }
        return try parser.endParsing()
    }
}
