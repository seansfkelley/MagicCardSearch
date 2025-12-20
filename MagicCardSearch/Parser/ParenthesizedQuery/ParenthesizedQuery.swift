struct ParenthesizedQuery {
    // Note that these are not guaranteed to be all filters; on parse error we stop trying and
    // return only those that we have definitely identified so far.
    let filters: [Range<String.Index>]
    
    static func tryParse(_ input: String) throws -> ParenthesizedQuery {
        let errorCapturer = ParenthesizedQueryErrorDelegate()

        let parser = ParenthesizedQueryParser()
        parser.errorCaptureDelegate = errorCapturer

        for (token, code) in try lexParenthesizedQuery(input) {
            try parser.consume(token: token, code: code)
        }
        return try parser.endParsing()
    }
}

private class ParenthesizedQueryErrorDelegate: ParenthesizedQueryParser.CitronErrorCaptureDelegate {
//    func shouldSaveErrorForCapturing(error: any Error) -> Bool {
//        <#code#>
//    }

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
