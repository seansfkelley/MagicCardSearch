import OSLog

private let logger = Logger(subsystem: "MagicCardSearch", category: "FilterQuery")

public enum FilterQuery<T: Codable & Sendable & Hashable & Equatable & CustomStringConvertible>: Codable, Sendable, Hashable, Equatable, CustomStringConvertible {
    case term(Polarity, T)
    case and(Polarity, [FilterQuery<T>])
    case or(Polarity, [FilterQuery<T>])

    public static func from(_ input: String, _ transform: @escaping (String) -> T?) -> FilterQuery<T>? {
        let parser = PartialFilterQueryParser()

        let trimmedInput = input.trimmingCharacters(in: .whitespaces)

        do {
            for (token, code) in try lexPartialFilterQuery(trimmedInput) {
                try parser.consume(token: token, code: code)
            }
            return try parser.endParsing().transformLeaves(using: transform)
        } catch {
            logger.debug("failed to parse disjunction error=\(error)")
            return nil
        }
    }

    public var negated: FilterQuery<T> {
        switch self {
        case .term(let polarity, let filterTerm):
            .term(polarity.negated, filterTerm)
        case .and(let polarity, let filters):
            .and(polarity.negated, filters)
        case .or(let polarity, let filters):
            .or(polarity.negated, filters)
        }
    }

    public var description: String {
        descriptionWithContext(parentOperator: nil)
    }

    private enum ParentOperator {
        case and
        case or
    }

    private func descriptionWithContext(parentOperator: ParentOperator?) -> String {
        switch self {
        case .term(let polarity, let filterTerm):
            return "\(polarity.description)\(filterTerm.description)"

        case .and(let polarity, let filters):
            let joined = filters.map { $0.descriptionWithContext(parentOperator: .and) }.joined(separator: " ")

            let result = polarity == .negative && filters.count > 1
                ? "(\(joined))"
                : joined

            return "\(polarity.description)\(result)"

        case .or(let polarity, let filters):
            let joined = filters.map { $0.descriptionWithContext(parentOperator: .or) }.joined(separator: " or ")

            let result = (parentOperator == .and) || (polarity == .negative && filters.count > 1)
                ? "(\(joined))"
                : joined

            return "\(polarity.description)\(result)"
        }
    }

    public func flattened() -> FilterQuery<T> {
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
    
    public func transformLeaves<U: Codable & Sendable & Hashable & Equatable & CustomStringConvertible>(
        using transform: (T) -> U?
    ) -> FilterQuery<U>? {
        switch self {
        case .term(let polarity, let value):
            guard let transformedValue = transform(value) else {
                return nil
            }
            return .term(polarity, transformedValue)
            
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
