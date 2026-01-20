import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "FilterQuery")

public protocol FilterQueryLeaf: Equatable, Hashable, Codable, CustomStringConvertible, Sendable {
    var negated: Self { get }
}

public enum FilterQuery<Term: FilterQueryLeaf>: FilterQueryLeaf {
    case term(Term)
    case and(Polarity, [FilterQuery<Term>])
    case or(Polarity, [FilterQuery<Term>])

    public static func from(_ input: String) -> FilterQuery<PolarityString>? {
        FilterQuery<PolarityString>.from(input) { $0 }
    }

    public static func from(_ input: String, _ transform: @escaping (PolarityString) -> Term?) -> FilterQuery<Term>? {
        let parser = PartialFilterQueryParser()

        let trimmedInput = input.trimmingCharacters(in: .whitespaces)

        do {
            for (token, code) in try lexPartialFilterQuery(trimmedInput) {
                try parser.consume(token: token, code: code)
            }
            return try parser.endParsing().flattened().transformLeaves(using: transform)
        } catch {
            logger.debug("failed to parse query error=\(error)")
            return nil
        }
    }

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
