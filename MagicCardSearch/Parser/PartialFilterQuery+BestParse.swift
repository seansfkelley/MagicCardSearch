import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "BestParse")

public extension PartialFilterQuery {
    enum BestParse: Equatable {
        case empty
        case valid(FilterQuery<PolarityString>)
        case autoterminated(FilterQuery<PolarityString>)
        case fallback(FilterQuery<PolarityString>)

        public var value: FilterQuery<PolarityString>? {
            switch self {
            case .empty: nil
            case .valid(let filter): filter
            case .autoterminated(let filter): filter
            case .fallback(let filter): filter
            }
        }
    }

    // swiftlint:disable:next cyclomatic_complexity
    static func from(
        _ input: String,
        autoclosePairedDelimiters: Bool = false,
    ) -> BestParse {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return .empty }

        lazy var fallback: BestParse = if trimmed.hasPrefix("-") {
            .fallback(.term(PolarityString(.negative, String(trimmed[trimmed.index(after: trimmed.startIndex)...]))))
        } else {
            .fallback(.term(PolarityString(.positive, trimmed)))
        }

        let tokens: [LexedPartialFilterQueryToken]
        do {
            tokens = try lexPartialFilterQuery(trimmed, allowingUnterminatedLiterals: autoclosePairedDelimiters)
        } catch {
            logger.debug("failed to lex query error=\(error)")
            return fallback
        }

        guard !tokens.isEmpty else { return .empty }

        let parser = PartialFilterQueryParser()

        if autoclosePairedDelimiters {
            let last = tokens.last!

            let closingQuote: String?
            if last.1 == .Verbatim {
                closingQuote = switch PartialFilterTerm.from(last.0.content).content.term {
                case .balanced, .bare: ""
                case .uninitiated: nil
                case .unterminated(let quote, _): quote.rawValue
                }
            } else {
                closingQuote = ""
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
                return fallback
            } else if !closingQuote!.isEmpty || unclosedParens > 0 {
                do {
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

                    return .autoterminated(try parser.endParsing().flattened())
                } catch {
                    logger.debug("failed to parse query error=\(error)")
                    return fallback
                }
            } else {
                // fall through
            }
        }

        do {
            for (token, code) in tokens {
                try parser.consume(token: token, code: code)
            }
            return .valid(try parser.endParsing().flattened())
        } catch {
            logger.debug("failed to parse query error=\(error)")
            return fallback
        }
    }
}
