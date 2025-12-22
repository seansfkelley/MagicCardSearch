struct PlausibleFilterRanges {
    // Note that these are not guaranteed to be all filters; on parse error we stop trying and
    // return only those that we have definitely identified so far.
    let ranges: [Range<String.Index>]
    
    static func from(_ input: String) throws -> PlausibleFilterRanges {
        let errorCapturer = PlausibleFilterRangesErrorCapturer()

        let parser = ParenthesizedQueryParser()
        parser.errorCaptureDelegate = errorCapturer
        
        let trimmedInput = input.trimmingCharacters(in: .whitespaces)
        let prefixOffset = input.prefixMatch(of: /\s*/)?.count ?? 0

        for (token, code) in try lexParenthesizedQuery(trimmedInput) {
            try parser.consume(token: token, code: code)
        }
        let disjunction = try parser.endParsing()
        return .init(
            ranges: collectRanges(in: disjunction).map { $0.offset(with: input, by: prefixOffset) }
        )
    }
    
    private static func collectRanges(in disjunction: ParenthesizedDisjunction) -> [Range<String.Index>] {
        var ranges: [Range<String.Index>] = []
        
        func helper(from conjunction: ParenthesizedConjunction) {
            for clause in conjunction.clauses {
                switch clause {
                case .filter(let range):
                    ranges.append(range)
                case .disjunction(let nestedDisjunction):
                    for nestedConjunction in nestedDisjunction.clauses {
                        helper(from: nestedConjunction)
                    }
                }
            }
        }
        
        for conjunction in disjunction.clauses {
            helper(from: conjunction)
        }
        
        return ranges
    }
}

private class PlausibleFilterRangesErrorCapturer: ParenthesizedQueryParser.CitronErrorCaptureDelegate {
    func shouldCaptureErrorOnQuery(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedDisjunction> {
        collectDisjunction(in: state)
    }
    
    func shouldCaptureErrorOnDisjunction(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedDisjunction> {
        collectDisjunction(in: state)
    }

    func shouldCaptureErrorOnConjunction(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedConjunction> {
        collectConjunction(in: state)
    }
    
    func shouldCaptureErrorOnParenthesized(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedDisjunction> {
        collectDisjunction(in: state)
    }
    
    private func collectDisjunction(in state: ParenthesizedQueryParser.CitronErrorCaptureState) -> CitronErrorCaptureResponse<ParenthesizedDisjunction> {
        var clauses: [ParenthesizedConjunction] = []
        
        for resolvedSymbol in state.resolvedSymbols {
            if let conjunction = resolvedSymbol.value as? ParenthesizedConjunction {
                clauses.append(conjunction)
            }
        }
        return .captureAs(.init(false, clauses))
    }
    
    private func collectConjunction(in state: ParenthesizedQueryParser.CitronErrorCaptureState) -> CitronErrorCaptureResponse<ParenthesizedConjunction> {
        var clauses: [ParenthesizedConjunction.Clause] = []
        
        for resolvedSymbol in state.resolvedSymbols {
            if let disjunction = resolvedSymbol.value as? ParenthesizedDisjunction {
                clauses.append(.disjunction(disjunction))
            }
        }
        return .captureAs(.init(clauses))
    }
}
