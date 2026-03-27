import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "BestParse")

public extension PartialFilterQuery {
    enum BestParse: Equatable, Sendable {
        case empty
        case valid(FilterQuery<PolarityString>)
        case autoclosed(FilterQuery<PolarityString>)
        case fallback(FilterQuery<PolarityString>)

        public var value: FilterQuery<PolarityString>? {
            switch self {
            case .empty: nil
            case .valid(let filter): filter
            case .autoclosed(let filter): filter
            case .fallback(let filter): filter
            }
        }
    }

    static func from(
        _ input: String,
        autoclosePairedDelimiters: Bool = false,
    ) -> BestParse {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .empty }

        lazy var fallback: PartialFilterQuery = if trimmed.hasPrefix("-") {
            .term(PolarityString(.negative, String(trimmed[trimmed.index(after: trimmed.startIndex)...])))
        } else {
            .term(PolarityString(.positive, trimmed))
        }

        let tokens: [LexedPartialFilterQueryToken]
        do {
            tokens = try lexPartialFilterQuery(trimmed, allowingUnclosedLiterals: autoclosePairedDelimiters)
        } catch {
            logger.debug("failed to lex query error=\(error)")
            return .fallback(fallback)
        }

        guard !tokens.isEmpty else { return .empty }

        if autoclosePairedDelimiters,
           let autoclosedResult = tryParsingWithAutoclose(tokens: tokens, withFallback: fallback) {
            return autoclosedResult
        }

        do {
            let parser = PartialFilterQueryParser()
            for (token, code) in tokens {
                try parser.consume(token: token, code: code)
            }
            return .valid(try parser.endParsing().flattened())
        } catch {
            logger.debug("failed to parse query error=\(error)")
            return .fallback(fallback)
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    private static func tryParsingWithAutoclose(
        tokens: [LexedPartialFilterQueryToken],
        withFallback fallback: @autoclosure () -> PartialFilterQuery,
    ) -> BestParse? {
        guard !tokens.isEmpty else { return nil }

        let last = tokens.last!

        let closingQuote: String? = if last.1 == .Verbatim {
            switch PartialFilterTerm.from(last.0.content).content.term {
            case .balanced, .bare: ""
            case .unopened: nil
            case .unclosed(let quote, _): quote.rawValue
            }
        } else {
            ""
        }

        var unclosedParens = 0
        for (_, kind) in tokens {
            let increment = switch kind {
            case .OpenParen: 1
            case .CloseParen: -1
            default: 0
            }

            unclosedParens += increment
        }

        if closingQuote == nil || unclosedParens < 0 {
            return .fallback(fallback())
        } else if !closingQuote!.isEmpty || unclosedParens > 0 {
            do {
                let parser = PartialFilterQueryParser()

                for (token, code) in tokens[..<(tokens.count - 1)] {
                    try parser.consume(token: token, code: code)
                }
                if let closingQuote, !closingQuote.isEmpty && tokens.last!.1 == .Verbatim {
                    try parser.consume(
                        // HACK: We know the parser doesn't care about the ranges, and the rest
                        // of this method doesn't either, so stub it.
                        token: .init(tokens.last!.0.content + closingQuote, tokens.last!.0.range),
                        code: .Verbatim,
                    )
                } else {
                    try parser.consume(token: tokens.last!.0, code: tokens.last!.1)
                }
                for _ in 0..<unclosedParens {
                    try parser.consume(
                        // HACK: We know the parser doesn't care about the ranges, and the rest
                        // of this method doesn't either, so stub it.
                        token: .init(")", tokens.last!.0.range),
                        code: .CloseParen,
                    )
                }

                return .autoclosed(try parser.endParsing().flattened())
            } catch {
                logger.debug("failed to parse query error=\(error)")
                return .fallback(fallback())
            }
        } else {
            return nil
        }
    }
}
