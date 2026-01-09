enum Polarity: Codable, Sendable, Hashable, Equatable {
    case positive
    case negative
}

private func quoteIfNecessary(_ string: String) -> String {
    if string.starts(with: "\"") {
        "'\(string)'"
    } else if string.starts(with: "'") {
        "\"\(string)\""
    } else if string.contains(" ") {
        "\"\(string)\""
    } else {
        string
    }
}

public enum FilterTerm: Codable, Sendable, Hashable, Equatable, CustomStringConvertible {
    case name(Bool, String)
    case basic(String, Comparison, String)
    case regex(String, Comparison, String)

    public var description: String {
        switch self {
        case .name(let isExact, let name):
            "\(isExact ? "!" : "")\(quoteIfNecessary(name))"
        case .basic(let filter, let comparison, let term):
            "\(filter)\(comparison)\(quoteIfNecessary(term))"
        case .regex(let filter, let comparison, let term):
            "\(filter)\(comparison)/\(term)/"
        }
    }
}

public enum SearchFilter2: Codable, Sendable, Hashable, Equatable, CustomStringConvertible {
    case term(Polarity, FilterTerm)
    case and(Polarity, [SearchFilter2])
    case or(Polarity, [SearchFilter2])

    private enum ParentOperator {
        case and
        case or
    }

    public var description: String {
        descriptionWithContext(parentOperator: nil)
    }
    
    private func descriptionWithContext(parentOperator: ParentOperator?) -> String {
        switch self {
        case .term(let polarity, let filterTerm):
            let prefix = polarity == .negative ? "-" : ""
            return "\(prefix)\(filterTerm.description)"
            
        case .and(let polarity, let filters):
            let joined = filters.map { $0.descriptionWithContext(parentOperator: .and) }.joined(separator: " ")

            let needsParens = polarity == .negative && filters.count > 1
            let result = needsParens ? "(\(joined))" : joined
            
            let prefix = polarity == .negative ? "-" : ""
            return "\(prefix)\(result)"
            
        case .or(let polarity, let filters):
            let joined = filters.map { $0.descriptionWithContext(parentOperator: .or) }.joined(separator: " or ")

            let needsParens = (parentOperator == .and) || (polarity == .negative && filters.count > 1)
            let result = needsParens ? "(\(joined))" : joined
            
            let prefix = polarity == .negative ? "-" : ""
            return "\(prefix)\(result)"
        }
    }

    public func flattened() -> SearchFilter2 {
        switch self {
        case .term:
            return self

        case .and(let polarity, let filters):
            var unwrappedFilters: [SearchFilter2] = []
            for filter in filters.map({ $0.flattened() }) {
                // Only unwrap contained ANDs that don't flip the polarity again.
                if case .and(.positive, let subFilters) = filter {
                    unwrappedFilters.append(contentsOf: subFilters)
                } else {
                    unwrappedFilters.append(filter)
                }
            }
            return .and(polarity, unwrappedFilters)
            
        case .or(let polarity, let filters):
            var unwrappedFilters: [SearchFilter2] = []
            for filter in filters.map({ $0.flattened() }) {
                // Only unwrap contained ORs that don't flip the polarity again.
                if case .or(.positive, let subFilters) = filter {
                    unwrappedFilters.append(contentsOf: subFilters)
                } else {
                    unwrappedFilters.append(filter)
                }
            }
            return .or(polarity, unwrappedFilters)
        }
    }
}
