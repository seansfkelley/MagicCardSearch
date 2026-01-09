public enum FilterTerm: Codable, Sendable, Hashable, Equatable, CustomStringConvertible {
    case name(Bool, String)
    case basic(String, Comparison, String)
    case regex(String, Comparison, String)

    public static func from(_ string: String) -> FilterTerm? {
        PartialFilterTerm.from(string).toComplete()
    }

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
