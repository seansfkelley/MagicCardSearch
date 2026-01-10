enum ParsedFilter {
    case empty
    case valid(FilterQuery<FilterTerm>)
    case autoterminated(FilterQuery<FilterTerm>)
    case fallback(FilterQuery<FilterTerm>)

    public var value: FilterQuery<FilterTerm>? {
        switch self {
        case .empty: nil
        case .valid(let filter): filter
        case .autoterminated(let filter): filter
        case .fallback(let filter): filter
        }
    }
}

extension String {
    func toFilter() -> ParsedFilter {
        let trimmed = trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else { return .empty }

        // FIXME: This is kind of gross; shouldn't we be able to unconditionally pass it through to
        // the parser and then it can tell us if it's valid or not?
        //
        // TODO: The parenthesized parser is a superset of PartialFilterTerm. This control flow
        // should be cleaned up to not require a regex.
        if (try? /^-?\(/.prefixMatch(in: trimmed)) != nil {
            return if let filter = FilterQuery.from(trimmed, FilterTerm.from) {
                .valid(filter)
            } else {
                // TODO: Should assign the negation correctly I think.
                .fallback(.term(.name(.positive, false, trimmed)))
            }
        } else {
            let partial = PartialFilterTerm.from(trimmed)
            if let filter = partial.toComplete() {
                return .valid(.term(filter))
            } else if let filter = partial.toComplete(autoterminateQuotes: true) {
                return .autoterminated(.term(filter))
            } else {
                // TODO: Should assign the negation correctly I think.
                return .fallback(.term(.name(.positive, false, trimmed)))
            }
        }
    }
}
