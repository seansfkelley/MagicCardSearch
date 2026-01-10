protocol EditableFilter {
    var suggestedEditingRange: Range<String.Index> { get }
    var isKnownFilterType: Bool { get }
}

public enum FilterTerm: FilterQueryLeaf, EditableFilter {
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

    var suggestedEditingRange: Range<String.Index> {
        let string = description
        switch self {
        case .name(let polarity, let isExact, let name):
            let quotes = requiredQuotingType(in: name)
            return string.range.inset(
                with: string,
                left: (polarity == .negative ? 1 : 0) + (isExact ? 1 : 0) + (quotes == .none ? 0 : 1),
                right: (quotes == .none ? 0 : 1),
            )
        case .basic(let polarity, let filter, let comparison, let term):
            let quotes = requiredQuotingType(in: term)
            return string.range.inset(
                with: string,
                left: (polarity == .negative ? 1 : 0) + filter.count + comparison.description.count + (quotes == .none ? 0 : 1),
                right: (quotes == .none ? 0 : 1),
            )
        case .regex(let polarity, let filter, let comparison, _):
            return string.range.inset(
                with: string,
                left: (polarity == .negative ? 1 : 0) + filter.count + comparison.description.count + 1,
                right: 1,
            )
        }
    }

    var isKnownFilterType: Bool {
        switch self {
        case .name: true
        case .basic(_, let filter, _, _): isScryfallFilter(filter)
        case .regex(_, let filter, _, _): isScryfallFilter(filter)
        }
    }

    private func requiredQuotingType(in string: String) -> RequiredQuotingType {
        if string.starts(with: "\"") {
            .single
        } else if string.starts(with: "'") || string.contains(" ") {
            .double
        } else {
            .none
        }
    }

    private func quoteIfNecessary(_ string: String) -> String {
        switch requiredQuotingType(in: string) {
        case .single: "'\(string)'"
        case .double: "\"\(string)\""
        case .none: string
        }
    }
}

private enum RequiredQuotingType {
    case single, double, none
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

private func isScryfallFilter(_ filter: String) -> Bool {
    scryfallFilterByType[filter.lowercased()] != nil
}

extension FilterQuery: EditableFilter where Term == FilterTerm {
    var suggestedEditingRange: Range<String.Index> {
        switch self {
        case .term(let filter):
            return filter.suggestedEditingRange
        case .and(let polarity, _), .or(let polarity, _):
            let string = description
            // This is a big dumb in that we should be able to calculate this from the source data
            // instead of inspecting the stringified form, but it's also simple and unambiguous.
            let hasParentheses = (try? /^-?\(/.prefixMatch(in: string)) != nil
            return string.range.inset(
                with: string,
                left: (polarity == .negative ? 1 : 0) + (hasParentheses ? 1 : 0),
                right: (hasParentheses ? 1 : 0),
            )
        }
    }
    
    var isKnownFilterType: Bool {
        switch self {
        case .term(let filter): filter.isKnownFilterType
        case .and(_, let filters), .or(_, let filters): filters.allSatisfy(\.isKnownFilterType)
        }
    }
}
