enum ParsedFilter {
    case empty
    case valid(SearchFilter)
    case autoterminated(SearchFilter)
    case fallback(SearchFilter)

    public var value: SearchFilter? {
        switch self {
        case .empty: nil
        case .valid(let filter): filter
        case .autoterminated(let filter): filter
        case .fallback(let filter): filter
        }
    }
}

extension String {
    func toSearchFilter() -> ParsedFilter {
        let trimmed = trimmingCharacters(in: .whitespaces)

        guard !trimmed.isEmpty else { return .empty }

        // FIXME: This is kind of gross; shouldn't we be able to unconditionally pass it through to
        // the parser and then it can tell us if it's valid or not?
        //
        // TODO: The parenthesized parser is a superset of PartialSearchFilter. This control flow
        // should be cleaned up to not require a regex.
        if (try? /^-?\(/.prefixMatch(in: trimmed)) != nil {
            return if let disjunction = ParenthesizedDisjunction.tryParse(trimmed), let filter = disjunction.toSearchFilter() {
                .valid(.disjunction(filter))
            } else {
                .fallback(.name(false, false, trimmed))
            }
        }

        let partial = PartialFilterTerm.from(trimmed)
        if let filter = partial.toComplete() {
            return .valid(filter)
        } else if let filter = partial.toComplete(autoterminateQuotes: true) {
            return .autoterminated(filter)
        }

        return .fallback(.name(false, false, trimmed))
    }
}
