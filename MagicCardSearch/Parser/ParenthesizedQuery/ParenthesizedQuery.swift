struct ParenthesizedQuery {
    // Note that these are not guaranteed to be all filters; on parse error we stop trying and
    // return only those that we have definitely identified so far.
    let filters: [Range<String.Index>]
    
    static func tryParse(_ input: String) throws -> ParenthesizedQuery {
        let errorCapturer = ParenthesizedQueryErrorDelegate()

        let parser = ParenthesizedQueryParser()
        parser.errorCaptureDelegate = errorCapturer
        
        let trimmedInput = input.trimmingCharacters(in: .whitespaces)
        let prefixOffset = input.prefixMatch(of: /\s*/)?.count ?? 0

        for (token, code) in try lexParenthesizedQuery(trimmedInput) {
            try parser.consume(token: token, code: code)
        }
        let query = try parser.endParsing()
        return .init(
            filters: query.filters.map { $0.offset(with: input, by: prefixOffset) }
        )
    }
}

private class ParenthesizedQueryErrorDelegate: ParenthesizedQueryParser.CitronErrorCaptureDelegate {
    func shouldCaptureErrorOnDisjunction(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedQuery> {
        collectAllRanges(in: state)
    }

    func shouldCaptureErrorOnConjunction(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedQuery> {
        collectAllRanges(in: state)
    }

    func shouldCaptureErrorOnQuery(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedQuery> {
        collectAllRanges(in: state)
    }
    
    func shouldCaptureErrorOnParenthesized(state: ParenthesizedQueryParser.CitronErrorCaptureState, error: any Error) -> CitronErrorCaptureResponse<ParenthesizedQuery> {
        collectAllRanges(in: state)
    }
    
    private func collectAllRanges(in state: ParenthesizedQueryParser.CitronErrorCaptureState) -> CitronErrorCaptureResponse<ParenthesizedQuery> {
        var ranges: [Range<String.Index>] = []
        for resolvedSymbol in state.resolvedSymbols {
            if let query = resolvedSymbol.value as? ParenthesizedQuery {
                ranges.append(contentsOf: query.filters)
            }
        }
        return .captureAs(.init(filters: ranges))
    }
}
