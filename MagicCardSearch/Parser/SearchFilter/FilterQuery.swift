import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "FilterQuery")

public protocol FilterQueryLeaf: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
    var negated: Self { get }
}

public enum BestParse: Equatable {
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

    // swiftlint:disable:next cyclomatic_complexity
    public static func from(
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

public enum FilterQuery<Term: FilterQueryLeaf>: FilterQueryLeaf {
    case term(Term)
    case and(Polarity, [FilterQuery<Term>])
    case or(Polarity, [FilterQuery<Term>])

    public var negated: FilterQuery<Term> {
        switch self {
        case .term(let term):
            .term(term.negated)
        case .and(let polarity, let filters):
            .and(polarity.negated, filters)
        case .or(let polarity, let filters):
            .or(polarity.negated, filters)
        }
    }

    public var description: String {
        descriptionWithContext(context: .root)
    }

    private enum DescriptionContext {
        case root, and, or
    }

    private func descriptionWithContext(context: DescriptionContext?) -> String {
        switch self {
        case .term(let term):
            return term.description

        case .and(let polarity, let filters):
            let joined = filters.map { $0.descriptionWithContext(context: .and) }.joined(separator: " ")

            let result = context == .root || (polarity == .negative && filters.count > 1)
                ? "(\(joined))"
                : joined

            return "\(polarity.description)\(result)"

        case .or(let polarity, let filters):
            let joined = filters.map { $0.descriptionWithContext(context: .or) }.joined(separator: " or ")

            let result = context == .root || context == .and || (polarity == .negative && filters.count > 1)
                ? "(\(joined))"
                : joined

            return "\(polarity.description)\(result)"
        }
    }

    public func flattened() -> FilterQuery<Term> {
        switch self {
        case .term:
            return self

        case .and(let polarity, let filters):
            let unwrappedFilters = filters.map { $0.flattened() }.flatMap { filter in
                // Only unwrap contained ANDs that don't flip the polarity again.
                if case .and(.positive, let subFilters) = filter {
                    subFilters
                } else {
                    [filter]
                }
            }

            return if unwrappedFilters.count == 1 {
                polarity == .positive ? unwrappedFilters.first! : unwrappedFilters.first!.negated
            } else {
                .and(polarity, unwrappedFilters)
            }

        case .or(let polarity, let filters):
            let unwrappedFilters = filters.map { $0.flattened() }.flatMap { filter in
                // Only unwrap contained ORs that don't flip the polarity again.
                if case .or(.positive, let subFilters) = filter {
                    subFilters
                } else {
                    [filter]
                }
            }

            return if unwrappedFilters.count == 1 {
                polarity == .positive ? unwrappedFilters.first! : unwrappedFilters.first!.negated
            } else {
                .or(polarity, unwrappedFilters)
            }
        }
    }
    
    public func transformLeaves<U: FilterQueryLeaf>(
        using transform: (Term) -> U?
    ) -> FilterQuery<U>? {
        switch self {
        case .term(let term):
            guard let transformedValue = transform(term) else {
                return nil
            }
            return .term(transformedValue)
            
        case .and(let polarity, let filters):
            var transformedFilters: [FilterQuery<U>] = []
            for filter in filters {
                guard let transformedFilter = filter.transformLeaves(using: transform) else {
                    return nil
                }
                transformedFilters.append(transformedFilter)
            }
            return .and(polarity, transformedFilters)
            
        case .or(let polarity, let filters):
            var transformedFilters: [FilterQuery<U>] = []
            for filter in filters {
                guard let transformedFilter = filter.transformLeaves(using: transform) else {
                    return nil
                }
                transformedFilters.append(transformedFilter)
            }
            return .or(polarity, transformedFilters)
        }
    }
}

public enum Polarity: Codable, Sendable, Hashable, Equatable, CustomStringConvertible {
    case positive
    case negative
    
    public var negated: Polarity {
        switch self {
        case .positive: .negative
        case .negative: .positive
        }
    }

    public var description: String {
        switch self {
        case .positive: ""
        case .negative: "-"
        }
    }
}
