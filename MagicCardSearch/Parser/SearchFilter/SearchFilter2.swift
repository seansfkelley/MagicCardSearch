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
}
