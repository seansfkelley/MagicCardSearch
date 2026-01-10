public enum FilterTerm: FilterQueryLeaf {
    case name(Polarity, Bool, String)
    case basic(Polarity, String, Comparison, String)
    case regex(Polarity, String, Comparison, String)

    public static func from(_ string: PolarityString) -> FilterTerm? {
        PartialFilterTerm.from(string.description).toComplete()
    }

    public var description: String {
        switch self {
        case .name(let polarity, let isExact, let name):
            "\(polarity)\(isExact ? "!" : "")\(quoteIfNecessary(name))"
        case .basic(let polarity, let filter, let comparison, let term):
            "\(polarity)\(filter)\(comparison)\(quoteIfNecessary(term))"
        case .regex(let polarity, let filter, let comparison, let term):
            "\(polarity)\(filter)\(comparison)/\(term)/"
        }
    }

    public var negated: FilterTerm {
        switch self {
        case .name(let polarity, let isExact, let name):
            .name(polarity.negated, isExact, name)
        case .basic(let polarity, let filter, let comparison, let term):
            .basic(polarity.negated, filter, comparison, term)
        case .regex(let polarity, let filter, let comparison, let term):
            .regex(polarity.negated, filter, comparison, term)
        }
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
}

public enum Comparison: String, Codable, Hashable, Equatable, CustomStringConvertible, Sendable {
    case including = ":"
    case equal = "="
    case notEqual = "!="
    case lessThan = "<"
    case lessThanOrEqual = "<="
    case greaterThan = ">"
    case greaterThanOrEqual = ">="

    public var description: String { rawValue }
}
