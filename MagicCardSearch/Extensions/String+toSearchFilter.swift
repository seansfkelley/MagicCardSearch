//
//  String+toSearchFilter.swift
//  MagicCardSearch
//
//  Created by Sean Kelley on 2025-12-28.
//
enum ParsedFilter {
    case empty
    case parsed(SearchFilter)
    case fallback(SearchFilter)

    public var value: SearchFilter? {
        switch self {
        case .empty: nil
        case .parsed(let filter): filter
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
        return if (try? /^-?\(/.prefixMatch(in: trimmed)) != nil {
            if let disjunction = ParenthesizedDisjunction.tryParse(trimmed), let filter = disjunction.toSearchFilter() {
                .parsed(.disjunction(filter))
            } else {
                .fallback(.name(false, false, trimmed))
            }
        } else if let filter = PartialSearchFilter.from(trimmed).toComplete() {
            .parsed(filter)
        } else {
            .fallback(.name(false, false, trimmed))
        }
    }
}
