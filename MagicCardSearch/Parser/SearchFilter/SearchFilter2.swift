enum Polarity: Codable, Sendable, Hashable, Equatable, CustomStringConvertible {
    case positive
    case negative
}

public enum FilterTerm: Codable, Sendable, Hashable, Equatable, CustomStringConvertible {
    case name(Bool, String)
    case basic(String, Comparison, String)
    case regex(String, Comparison, String)
}

public enum SearchFilter2: Codable, Sendable, Hashable, Equatable, CustomStringConvertible {
    case term(Polarity, FilterTerm)
    case and(Polarity, [SearchFilter2])
    case or(Polarity, [SearchFilter2])

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
